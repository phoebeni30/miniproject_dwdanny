### datawithdanny
#### EMAIL MARKETING CASE STUDY OVERVIEW

We have been tasked by the DVD Rental Co marketing team to help them generate the analytical inputs required to drive their very first customer email campaign.
The marketing team expects their personalised emails to drive increased sales and engagement from the DVD Rental Co customer base.
The main initiative is to share insights about each customer’s viewing behaviour to demonstrate DVD Rental Co’s relentless focus on customer experience.
The insights requested by the marketing team include key statistics about each customer’s top 2 categories and favourite actor. There are also 3 personalised recommendations based off each customer’s previous viewing history as well as titles which are popular with other customers.
<p align="center">
    <img src="https://i.imgur.com/5LnI0HW.png">

##### A. Category Insights
###### 1. Top Category.
- What was the top category watched by total rental count?
- How many total films have they watched in their top category and how does it compare to the DVD Rental Co customer base?
- How many more films has the customer watched compared to the average DVD Rental Co customer?
- How does the customer rank in terms of the top X% compared to all other customers in this film category?
- What are the top 3 film recommendations in the top category ranked by total customer rental count which the customer has not seen before?

###### 2. Second Category
- What is the second ranking category by total rental count?
- What proportion of each customer’s total films watched does this count make?
- What are top 3 recommendations for the second category which the customer has not yet seen before?

##### B. Actor Insights
- Which actor has featured in the customer’s rental history the most?
- How many films featuring this actor has been watched by the customer?
- What are the top 3 recommendations featuring this same actor which have not been watched by the customer?

------
### SOLUTION VISUALIZATION
## TOP CATEGORIES AND TOP CATEGORY INSIGHTS
#### 1. Create temp table to join relevant table
    DROP TABLE IF EXISTS completed_join_dataset;
    select r.customer_id, c.category_id, c.name as category_name, f.film_id, f.title, r.rental_date
    into completed_join_dataset  --Create temp table completed_join_dataset
    from dbo.rental r
    inner join dbo.inventory i on r.inventory_id = i.inventory_id
    inner join dbo.film f on i.film_id = f.film_id
    inner join dbo.film_category fc on f.film_id = fc.film_id
    inner join dbo.category c on fc.category_id = c.category_id
    
<p align="center">
    <img src="https://i.imgur.com/koWmPKG.png">

#### 2. Calculate count of each customer and category. Create temp table category_counts
    DROP TABLE IF EXISTS category_counts
    select c.customer_id,
            category_name, 
            count(*) as rental_count,
            max(rental_date) as lastest_rental_date
    into category_counts  --Create temp table category_counts
    from completed_join_dataset c
    group by c.customer_id, c.category_name

<p align="center">
    <img src="https://i.imgur.com/LaDX9W7.png">

#### 3. Calculate total number of films customer has watched per each top 2 categories, [rental_count]. Create temp table top 2_category
    DROP TABLE IF EXISTS top_2_category;
    with cte_top_category as (
    select cc.customer_id, 
        cc.category_name, 
        cc.rental_count,
        ROW_NUMBER() OVER(partition by cc.customer_id order by cc.customer_id asc, cc.rental_count desc, cc.lastest_rental_date desc)
        as category_ranking
        from category_counts cc )
    select cte_top_category.customer_id,
            cte_top_category.category_name,
            cte_top_category.rental_count,
            cte_top_category.category_ranking
    into top_2_category --Create temp table top 2_category
    from cte_top_category
    where category_ranking <=2
    
<p align="center">
    <img src="https://i.imgur.com/cEaWHn1.png">

#### 4. Calculate how many more films has the customer watched compared to the average DVD Rental Co customer
    DROP TABLE IF EXISTS avg_category_counts
    select category_counts.category_name, 
            avg(category_counts.rental_count) as avg_category_count
    into avg_category_counts -- Create temp table avg_category_counts
    from category_counts
    group by category_counts.category_name
    -------Check temp table avg_category_counts
    select * from avg_category_counts
    order by category_name
<p align="center">
    <img src="https://i.imgur.com/d6Tb1N8.png">

#### 5. Calculate how does the customer rank in terms of the top X% compared to all other customers in this film category
       DROP TABLE IF EXISTS category_percentiles;
        with cte_percentile as 
        (select top_2_category.customer_id,
                top_2_category.category_name as top2_category_name,
                top_2_category.rental_count,
                category_counts.category_name,
                top_2_category.category_ranking,
                PERCENT_RANK() over(partition by category_counts.category_name order by category_counts.rental_count desc)
                as raw_category_percentile
        from category_counts
        left join top_2_category 
        on category_counts.customer_id = top_2_category.customer_id)
        select customer_id,
                top2_category_name,
                rental_count,
                category_ranking,
                (case 
                    when round(100*raw_category_percentile,0) = 0 then 1
                    else round(100*raw_category_percentile,0)
                end) 
                as percentile
        into category_percentiles  -- Create temp table category_percentiles
        from cte_percentile 
        where cte_percentile.category_ranking = 1
            and top2_category_name = category_name
        order by customer_id asc
<p align="center">
    <img src="https://i.imgur.com/NGbZm0r.png">
  
#### 6. Calculate the total films that customer has watched in their history rental
    DROP TABLE IF EXISTS total_film_counts;
    select category_counts.customer_id, sum(category_counts.rental_count) as total_film_count
    into total_film_counts -- Create temp table total_film_counts
    from category_counts
    group by category_counts.customer_id
    order by category_counts.customer_id asc
<p align="center">
    <img src="https://i.imgur.com/4WrjCLB.png">
  
#### 7. Generate 1st category insight - create temp table top_1_category_insight
    DROP TABLE IF EXISTS top_1_category_insight;
    select t.customer_id,
            t.category_name,
            t.rental_count,
            (t.rental_count - c.avg_category_count) as avg_comparison,
            p.percentile,
            round(100*t.rental_count/f.total_film_count,0) as film_percentage
    into top_1_category_insight  --create temp table top_1_category_insight
    from (select * 
            from top_2_category
            where category_ranking = 1) as t
    inner join avg_category_counts c on  t.category_name = c.category_name
    inner join category_percentiles p on t.customer_id = p.customer_id
    inner join total_film_counts f on t.customer_id = f.customer_id
    order by t.customer_id
<p align="center">
    <img src="https://i.imgur.com/744p7F7.png">

#### 8. Generate 2nd category insight - create temp table top_2_category_insight
    DROP TABLE IF EXISTS top_2_category_insight;
    select t.customer_id,
            t.category_name,
            t.rental_count,
            round(100*t.rental_count/f.total_film_count,0) as film_percentage
    into top_2_category_insight  --create temp table top_2_category_insight
    from (select * 
            from top_2_category
            where category_ranking = 2) as t
    inner join total_film_counts f on t.customer_id = f.customer_id
    order by t.customer_id
<p align="center">
    <img src="https://i.imgur.com/PZb2vzz.png">

## CATEGORY RECOMMENDATIONS
#### 1. Generate a summarised film count table with the category included. Create temp table film_count
    DROP TABLE IF EXISTS film_counts
    select distinct 
        film_id,
        title,
        category_name,
        count(*)  over(partition by film_id) as film_count
    into film_counts --create temp table film_counts
    from completed_join_dataset

<p align="center">
    <img src="https://i.imgur.com/fjNRvoS.png">
  
#### 2. Create a previously watched films for the top 2 categories to exclude for each customer
    DROP TABLE IF EXISTS category_film_exclusions;
    select distinct 
        customer_id,
        film_id
    into category_film_exclusions --create temp table category_film_exclusions
    from completed_join_dataset
<p align="center">
    <img src="https://i.imgur.com/6wqHUxQ.png">
  
#### 3. Create temp table final for category_recommendation
    DROP TABLE IF EXISTS category_recommendation;
    with cte_film_ranking as (
    select t.customer_id,
            t.category_name,
            t.category_ranking,
            f.film_id,
            f.title as film_title,
            f.film_count,
            DENSE_RANK() OVER(partition by t.customer_id, t.category_ranking order by f.film_count desc, f.title ) 
            as film_ranking
    from top_2_category t 
    inner join film_counts f 
    on t.category_name = f.category_name
    where not exists 
        (select * 
        from category_film_exclusions
        where category_film_exclusions.customer_id = t.customer_id
            and category_film_exclusions.film_id = f.film_id
        )
    )
    select  cte_film_ranking.customer_id,
            customer.first_name,
            customer.last_name,
            cte_film_ranking.category_name,
            cte_film_ranking.category_ranking,
            cte_film_ranking.film_id,
            cte_film_ranking.film_title,
            cte_film_ranking.film_count,
            cte_film_ranking.film_ranking
    into category_recommendation -- Create temp table category_recommendation
    from cte_film_ranking
    inner join customer
    on customer.customer_id = cte_film_ranking.customer_id
    where cte_film_ranking.film_ranking <=3
<p align="center">
    <img src="https://i.imgur.com/pUbuLNx.png">

## TOP ACTOR & ACTOR INSIGHTS
#### 1. Create join temp table for actor dataset
    DROP TABLE IF EXISTS actor_film_dataset;
    select r.customer_id,
            r.rental_id,
            r.rental_date,
            f.film_id,
            f.title,
            a.actor_id,
            concat(a.first_name,' ',a.last_name) as full_name
    into actor_film_dataset
    from rental r 
    inner join inventory v on r.inventory_id = v.inventory_id
    inner join film f on f.film_id = v.film_id
    --title
    inner join film_category fc on fc.film_id = f.film_id
    inner join category c on c.category_id = fc.category_id
    --actor
    inner join film_actor fa on fa.film_id = f.film_id
    inner join actor a on a.actor_id = fa.actor_id
    order by customer_id
<p align="center">
    <img src="https://i.imgur.com/lJjIHPB.png">
    
#### 2. Create temp table for actor_rental_count - Calculate the actor that customers watches
    DROP TABLE IF EXISTS actor_rental_counts;
    select ad.customer_id,
             ad.actor_id,
            ad.full_name,
            count(*) as actor_rental_count,
            max(ad.rental_date) as latest_rental_date
    into actor_rental_counts
    from actor_film_dataset ad 
    group by ad.customer_id, ad.full_name, ad.actor_id
    order by ad.customer_id asc, count(*) desc
<p align="center">
    <img src="https://i.imgur.com/FRil97z.png">
    
#### 3. Create temp table for actor_rental_count - Calculate the actor that customers watches THE MOSTTT
    DROP TABLE IF EXISTS top_actor_rental_count;
    with cte_actor_ranking as (
    select actor_rental_counts.customer_id,
            actor_rental_counts.actor_id,
            actor_rental_counts.full_name,
            actor_rental_counts.actor_rental_count,
            ROW_NUMBER() OVER(partition by actor_rental_counts.customer_id order by actor_rental_counts.actor_rental_count desc)
            as actor_ranking
    from actor_rental_counts
    )
    select * 
    into top_actor_rental_count
    from cte_actor_ranking
    where cte_actor_ranking.actor_ranking = 1
<p align="center">
    <img src="https://i.imgur.com/XUU2OQh.png">

## ACTOR RECOMMENDATIONS
#### 1. Create table count for all actor and all film 
    DROP TABLE IF EXISTS total_actor_film_counts;
    select distinct 
            title,
            full_name,
            count(*) OVER(partition by title, full_name) as total_actor_film_count
    into total_actor_film_counts -- CREATE TEMP TABLE total_actor_film_counts
    from actor_film_dataset
<p align="center">
    <img src="https://i.imgur.com/8uIfYtw.png">
    
#### 2. Create exclusion table for customer, title, actor
    DROP TABLE IF EXISTS exclusion_actor_film;
    select distinct
            customer_id,
            title,
            full_name
    into exclusion_actor_film -- CREATE TEMP TABLE exclusion_actor_film
    from actor_film_dataset
<p align="center">
    <img src="https://i.imgur.com/6UHlSlx.png">
    
#### 3. Create table join for top 1 ranking actor with title, set ranking partition by customer and actor. And create table anti join with exclusion table to find the final result table
    DROP TABLE IF EXISTS actor_film_recommendation;
    with cte_actor_film_rankings as (
    select top_actor_rental_count.customer_id,
        total_actor_film_counts.full_name,
        top_actor_rental_count.actor_ranking,
        total_actor_film_counts.title,
        total_actor_film_counts.total_actor_film_count,
        dense_rank() 
        over(partition by top_actor_rental_count.customer_id,
                                        top_actor_rental_count.full_name
            order by total_actor_film_counts.total_actor_film_count desc,
                                    total_actor_film_counts.title)
        as actor_film_ranking
    from total_actor_film_counts
    inner join top_actor_rental_count 
    on total_actor_film_counts.full_name = top_actor_rental_count.full_name
    where not exists (
            select *
            from exclusion_actor_film
            where exclusion_actor_film.customer_id = top_actor_rental_count.customer_id
                and exclusion_actor_film.title = total_actor_film_counts.title
        )
    )
    select customer.customer_id,
            customer.first_name,
            customer.last_name,
            cte_actor_film_rankings.actor_ranking,
            cte_actor_film_rankings.full_name,
            cte_actor_film_rankings.title,
            cte_actor_film_rankings.total_actor_film_count,
            cte_actor_film_rankings.actor_film_ranking
    into actor_film_recommendation -- CREATE TEMP TABLE actor_film_recommendation
    from cte_actor_film_rankings
    inner join customer
    on customer.customer_id = cte_actor_film_rankings.customer_id
    where actor_film_ranking <=3
    order by customer_id, total_actor_film_count desc
<p align="center">
    <img src="https://i.imgur.com/CKe6XTN.png">
