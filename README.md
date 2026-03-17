# datawithdanny
### Foodie-Fi Subscription Saas Product

#### Business Overview
Subscription based businesses are super popular and Danny realised that there was a large gap in the market - he wanted to create a new streaming service that only had food related content - something like Netflix but with only cooking shows!

Danny finds a few smart friends to launch his new startup Foodie-Fi in 2020 and started selling monthly and annual subscriptions, giving their customers unlimited on-demand access to exclusive food videos from around the world!!

Danny created Foodie-Fi with a data driven mindset and wanted to ensure all future investment decisions and new features were decided using data. This case study focuses on using subscription style digital data to answer important business questions.

#### Business Requirement

1. Create table transaction payment based on available tables
2. Cohort churn rate analysis


-----
### Solution Visualization
#### Transaction payment table in 2020

Problem: Subsription table just show customer journey by subscription date. 
Objective: Create transaction table with monthly payment (include date and price) 
Approach: 
- Classify customer semgents by customer journey
- Declare single variables, cursor variables and use while loop to insert monthly payment data row into subscription table

--Update the accurate price
      UPDATE dbo.plans
      SET price = (
                      case when price is not null then price/100 else price end 
      )

--A. Transaction payment table in 2020
-----Create temp table lead_table

      DROP TABLE IF EXISTS lead_table;
      with cte_lead_table as (
              select s.customer_id, 
                      s.plan_id,
                      s.start_date,
                      lead(s.plan_id) over(partition by s.customer_id order by s.start_date) lead_plan_id,
                      lead(s.start_date) over(partition by s.customer_id order by s.start_date) lead_start_date
              from dbo.subscriptions s 
      )
      select * 
      into lead_table
      from cte_lead_table
      where year(start_date) = 2020
      and plan_id != 0 
    
      select * from lead_table
      
      /* select plan_id, lead_plan_id,count(*)
      from lead_table
      group by plan_id, lead_plan_id
      order by plan_id asc */
  
----1: non churn monthly customer (1,N - 2,N) 
---------create temp_case1_transaction

      drop table if exists temp_case1_transaction
      select customer_id, plan_id, start_date, DATEDIFF(DAY,start_date, '2020-12-31')/30 as count_month
      into temp_case1_transaction
      from lead_table
      where
              lead_plan_id is null 
              and plan_id not in (3,4)
      
      --select * from temp_case1_transaction
      
      declare transactiondatecursorcase1 CURSOR FOR 
              select t.customer_id, t.plan_id, t.start_date, t.count_month 
              from temp_case1_transaction t
      
      open transactiondatecursorcase1
      
      declare @customeridcase1 INT 
      declare @planidcase1 INT 
      declare @startdatecase1 DATETIME
      declare @countmonthcase1 int = (select count_month from temp_case1_transaction where customer_id = @customeridcase1)
      
      FETCH NEXT FROM transactiondatecursorcase1 into @customeridcase1,@planidcase1, @startdatecase1, @countmonthcase1
      WHILE @@FETCH_STATUS = 0        
      BEGIN
              declare @dateaddcase1 int
              set @dateaddcase1 = 1
              while @dateaddcase1 <= @countmonthcase1
              BEGIN   
                      INSERT INTO temp_case1_transaction (customer_id, plan_id, start_date, count_month) 
                      VALUES (@customeridcase1, @planidcase1,DATEADD(month,@dateaddcase1,@startdatecase1),'')
                      SET @dateaddcase1 = @dateaddcase1 + 1
              END 
      
      FETCH NEXT FROM transactiondatecursorcase1 into @customeridcase1,@planidcase1, @startdatecase1, @countmonthcase1
      END
      
      CLOSE transactiondatecursorcase1
      DEALLOCATE transactiondatecursorcase1
      
      
      select count(distinct customer_id) from temp_case1_transaction
      order by customer_id asc, start_date asc


----2: Annual user (3)
---------create temp_case2_transaction

              drop table if exists temp_case2_transaction
              select customer_id, plan_id, start_date
              into temp_case2_transaction
              from lead_table
              where plan_id = 3
              
              select count(*) from temp_case2_transaction


----3: churn from basic/ pro monthly (1,4 - 2,4)
---------create temp_case3_transaction

              drop table if exists temp_case3_transaction
              select customer_id, plan_id, start_date,
                      DATEDIFF(DAY, start_date, lead_start_date)/30 as count_month
              into temp_case3_transaction
              from lead_table
              where plan_id in (1,2) and lead_plan_id = 4
              
              --select * from temp_case3_transaction
              
              declare transactiondatecursorcase3 CURSOR FOR 
                      select customer_id, plan_id, start_date, count_month 
                      from temp_case3_transaction
              
              open transactiondatecursorcase3
              
              declare @customeridcase3 INT 
              declare @planidcase3 INT 
              declare @startdatecase3 DATETIME
              declare @countmonthcase3 int = (select count_month from temp_case3_transaction where customer_id = @customeridcase3)
              
              FETCH NEXT FROM transactiondatecursorcase3 into @customeridcase3,@planidcase3, @startdatecase3, @countmonthcase3
              WHILE @@FETCH_STATUS = 0
              BEGIN
                      declare @dateaddcase3 int
                      set @dateaddcase3 = 1
                      while @dateaddcase3 <= @countmonthcase3
                      BEGIN   
                              INSERT INTO temp_case3_transaction (customer_id, plan_id, start_date, count_month) 
                              VALUES (@customeridcase3, @planidcase3,DATEADD(month,@dateaddcase3,@startdatecase3),'')
                              SET @dateaddcase3 = @dateaddcase3 + 1
                      END 
                      
              FETCH NEXT FROM transactiondatecursorcase3 into @customeridcase3,@planidcase3, @startdatecase3, @countmonthcase3
              END
              
              CLOSE transactiondatecursorcase3
              DEALLOCATE transactiondatecursorcase3
              
              
              select count(distinct customer_id) from temp_case3_transaction
              order by customer_id asc, start_date asc

----4: basic to pro monthly and pro annual (1,2 - 1,3)

              drop table if exists temp_case4_transaction
              select customer_id, plan_id, start_date,
                      DATEDIFF(DAY, start_date, lead_start_date)/30 as count_month
              into temp_case4_transaction
              from lead_table
              where plan_id = 1 and lead_plan_id in (2,3)
              
              --select * from temp_case4_transaction
              
              declare transactiondatecursorcase4 CURSOR FOR 
                      select customer_id, plan_id, start_date, count_month 
                      from temp_case4_transaction
              
              open transactiondatecursorcase4
              
              declare @customeridcase4 INT 
              declare @planidcase4 INT 
              declare @startdatecase4 DATETIME
              declare @countmonthcase4 int = (select count_month from temp_case4_transaction where customer_id = @customeridcase4)
              
              FETCH NEXT FROM transactiondatecursorcase4 into @customeridcase4,@planidcase4, @startdatecase4, @countmonthcase4
              WHILE @@FETCH_STATUS = 0
              BEGIN
                      declare @dateaddcase4 int
                      set @dateaddcase4 = 1
                      while @dateaddcase4 <= @countmonthcase4
                      BEGIN   
                              INSERT INTO temp_case4_transaction (customer_id, plan_id, start_date, count_month) 
                              VALUES (@customeridcase4, @planidcase4,DATEADD(month,@dateaddcase4,@startdatecase4),'')
                              SET @dateaddcase4 = @dateaddcase4 + 1
                      END 
                      
              FETCH NEXT FROM transactiondatecursorcase4 into @customeridcase4,@planidcase4, @startdatecase4, @countmonthcase4
              END
              
              CLOSE transactiondatecursorcase4
              DEALLOCATE transactiondatecursorcase4
              
              
              select count(distinct customer_id) from temp_case4_transaction
              order by customer_id asc, start_date asc

----5: pro monthly to pro annual (2,3)

              drop table if exists temp_case5_transaction
              select customer_id, plan_id, start_date,
                      (DATEDIFF(DAY, start_date, lead_start_date)/30 - 1) as count_month
              into temp_case5_transaction
              from lead_table
              where plan_id = 2 and lead_plan_id = 3
              
              --select * from temp_case5_transaction
              
              declare transactiondatecursorcase5 CURSOR FOR 
                      select customer_id, plan_id, start_date, count_month 
                      from temp_case5_transaction
              
              open transactiondatecursorcase5
              
              declare @customeridcase5 INT 
              declare @planidcase5 INT 
              declare @startdatecase5 DATETIME
              declare @countmonthcase5 int = (select count_month from temp_case5_transaction where customer_id = @customeridcase5)
              
              FETCH NEXT FROM transactiondatecursorcase5 into @customeridcase5,@planidcase5, @startdatecase5, @countmonthcase5
              WHILE @@FETCH_STATUS = 0
              BEGIN
                      declare @dateaddcase5 int
                      set @dateaddcase5 = 1
                      while @dateaddcase5 <= @countmonthcase5
                      BEGIN   
                              INSERT INTO temp_case5_transaction (customer_id, plan_id, start_date, count_month) 
                              VALUES (@customeridcase5, @planidcase5,DATEADD(month,@dateaddcase5,@startdatecase5),'')
                              SET @dateaddcase5 = @dateaddcase5 + 1
                      END 
                      
              FETCH NEXT FROM transactiondatecursorcase5 into @customeridcase5,@planidcase5, @startdatecase5, @countmonthcase5
              END
              
              CLOSE transactiondatecursorcase5
              DEALLOCATE transactiondatecursorcase5
              
              
              select count(distinct customer_id) from temp_case5_transaction
              order by customer_id asc, start_date asc


--final union table: union all temp_caseX_transaction

              drop table if exists temp_union_transaction;
              with cte_union as (
                      select a.customer_id, a.plan_id, a.start_date
                      from temp_case1_transaction a
                      union all 
                      select *
                      from temp_case2_transaction b 
                      union all 
                      select c.customer_id, c.plan_id, c.start_date
                      from temp_case3_transaction c 
                      union all 
                      select d.customer_id, d.plan_id, d.start_date
                      from temp_case4_transaction d
                      union all 
                      select e.customer_id, e.plan_id, e.start_date
                      from temp_case5_transaction e
                      
              )
              select *
              into temp_union_transaction
              from cte_union 
              where year(cte_union.start_date) != 2021
              
              select * from temp_union_transaction
              where customer_id = 179
              select count(distinct customer_id) from temp_union_transaction
              order by customer_id asc, start_date asc

--final table transaction with price change

              drop table if exists temp_final_transaction_payment;
              with cte_price as (
                      select tu.customer_id, tu.plan_id, tu.start_date,
                              p.price,
                              lead(tu.plan_id,1) OVER(partition by tu.customer_id order by tu.start_date) as lead_plan_id
                      from temp_union_transaction tu 
                      inner join dbo.plans p 
                      on p.plan_id = tu.plan_id
              )
              select cp.customer_id, 
                      cp.plan_id,
                      cp.start_date,
                      (
                              case    
                                      when cp.plan_id = 1 and cp.lead_plan_id = 2 then round(((select price from dbo.plans where plan_id = 2) - price),1)
                                      when cp.plan_id = 1 and cp.lead_plan_id = 3 then round(((select price from dbo.plans where plan_id = 3) - price),1)
                                      else price 
                              end
                      ) price
              into temp_final_transaction_payment
              from cte_price cp 
              order by customer_id asc, start_date asc
              
              select count(distinct customer_id) from temp_final_transaction_payment

#### Results
Subscription table
<p align="center">
    <img src="https://i.imgur.com/U9RlG0Z.png">

Transaction table
<p align="center">
    <img src="https://i.imgur.com/F3M6Lfh.png">


### Cohort churn rate analysis

-----Create temp table after_trial_table

              drop table if exists month_after_trial_table;
              with after_trial_table as (
                      select p.customer_id,
                              p.plan_id,
                              p.start_date,
                              MONTH(p.start_date) as month_num,
                              ROW_NUMBER() OVER(partition by customer_id order by start_date asc) as row_num
                      from dbo.subscriptions p
                      where p.plan_id !=0 and p.plan_id !=4 and year(p.start_date) = 2020)
              select t.month_num, 
                      count(distinct customer_id) as total_user_after_trial
              into month_after_trial_table
              from after_trial_table t 
              where t.row_num = 1
              group by t.month_num
              
              
              select * from month_after_trial_table

-----Create temp table month_trial_table

              drop table if exists month_trial_table;
              with trial_table as (
                      select s.customer_id, 
                              s.plan_id,
                              s.start_date,
                              MONTH(s.start_date) as month_num
                      from dbo.subscriptions s
                      where year(s.start_date) = 2020 and plan_id = 0
              )
              select  t.month_num,
                      count(distinct t.customer_id) total_trial
              into month_trial_table
              from trial_table t
              group by t.month_num

-----Create table show number_user_trial and number_user_subscription_after_trial

              select t.month_num,
                      t.total_trial,
                      a.total_user_after_trial
              from month_trial_table t
              inner join month_after_trial_table  a
              on t.month_num = a.month_num


-----Create temp table cohort retention

              drop table if exists cohort_customer_lifetime;
              with fact_table as (
                      select p.customer_id,
                              p.plan_id,
                              p.start_date,
                              month(p.start_date) as month_fact,
                              ROW_NUMBER() OVER(PARTITION BY p.customer_id order by p.start_date asc) as row_num
                      from temp_final_transaction_payment p
              )
              ,
              first_join as (
                      select *   
                      from fact_table
                      where row_num = 1
              ),
              month_diff_table as (
                      select t.customer_id,
                              t.plan_id,
                              t.start_date,
                              t.month_fact,
                              f.month_fact as month_first_join,
                              (t.month_fact - f.month_fact) as month_diff,
                              CONCAT('M',(t.month_fact - f.month_fact)) as month_lifetime
                      from fact_table t 
                      left join first_join f 
                      on t.customer_id = f.customer_id
              )
              select d.month_first_join,
                      d.month_lifetime,
                      count(distinct d.customer_id) as total_user
              into cohort_customer_lifetime
              from month_diff_table d
              group by d.month_first_join, d.month_lifetime
              order by d.month_first_join asc, d.month_lifetime asc
              
              
              select * from cohort_customer_lifetime
              order by month_first_join asc, total_user desc, month_lifetime asc

#### Results
<p align="center">
    <img src="https://i.imgur.com/XPY2ClU.png">



