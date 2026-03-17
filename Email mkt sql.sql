--Check join type between customer and rental table 
select count(distinct c.customer_id ), count(*) from dbo.customer c
select count(distinct r.customer_id), count(*) from dbo.rental r 
---check distribution in customer table. Relation of fkey customer_id in "customer" table is 1-1 --
with cte as (select c.customer_id, count(*) as row_count
from dbo.customer c 
group by c.customer_id)
select c.row_count, count(c.customer_id) as fkey_count
from cte c 
group by c.row_count

---check distribution in rental table. Relation of fkey customer_id in "rental" table is 1-n
with cte as (select c.customer_id, count(*) as row_count
from dbo.rental c 
group by c.customer_id)
select c.row_count, count(c.customer_id) as fkey_count
from cte c 
group by c.row_count
order by c.row_count

---check overlapping or missing of f.key in customer table and rental table
select count(distinct c.customer_id) as fkey_count
from dbo.customer c 
where not exists (
    select r.customer_id
    from dbo.rental r 
    where r.customer_id = c.customer_id
)

select count(distinct r.customer_id) as fkey_count
from dbo.rental r
where not exists (
    select c.customer_id
    from dbo.customer c
    where r.customer_id = c.customer_id
)


--------------------------------------------
--------------------------------------------
--########## TOP CATEGORIES AND TOP CATEGORY INSIGHTS ##########
--##############################################################
--#1 Create temp table to join relevant table
--------------------------------------------
DROP TABLE IF EXISTS completed_join_dataset;
    select r.customer_id, c.category_id, c.name as category_name, f.film_id, f.title, r.rental_date
    into completed_join_dataset  --Create temp table completed_join_dataset
    from dbo.rental r
    inner join dbo.inventory i on r.inventory_id = i.inventory_id
    inner join dbo.film f on i.film_id = f.film_id
    inner join dbo.film_category fc on f.film_id = fc.film_id
    inner join dbo.category c on fc.category_id = c.category_id
-------Check temp table completed_join_dataset
select * from completed_join_dataset
where customer_id = 130

--------------------------------------------
--#2 Calculate count of each customer and category. Create temp table category_counts
--------------------------------------------
DROP TABLE IF EXISTS category_counts
select c.customer_id,
        category_name, 
        count(*) as rental_count,
        max(rental_date) as lastest_rental_date
into category_counts  --Create temp table category_counts
from completed_join_dataset c
group by c.customer_id, c.category_name
-------Check temp table category_counts
select * from category_counts
order by customer_id asc, rental_count desc

--------------------------------------------
--#3 Calculate total number of films customer has watched per each top 2 categories, [rental_count]. Create temp table top 2_category
--------------------------------------------
DROP TABLE IF EXISTS top_2_category
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
-------Check temp table top 2_category
select * from top_2_category

--------------------------------------------
--#4 Calculate How many more films has the customer watched compared to the average DVD Rental Co customer?
-------Calculate avg_category_counts
--------------------------------------------
DROP TABLE IF EXISTS avg_category_counts
select category_counts.category_name, 
        avg(category_counts.rental_count) as avg_category_count
into avg_category_counts -- Create temp table avg_category_counts
from category_counts
group by category_counts.category_name
-------Check temp table avg_category_counts
select * from avg_category_counts
order by category_name

--------------------------------------------
--#5 Calculate How does the customer rank in terms of the top X% compared to all other customers in this film category?
--------------------------------------------
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
-------Check temp table category_percentiles
select * from category_percentiles
order by customer_id asc

--------------------------------------------
--#6 Calculate the total films that customer has watched in their history rental
--------------------------------------------
DROP TABLE IF EXISTS total_film_counts;
select category_counts.customer_id, sum(category_counts.rental_count) as total_film_count
into total_film_counts -- Create temp table total_film_counts
from category_counts
group by category_counts.customer_id
order by category_counts.customer_id asc
-------Check temp table total_film_counts
select * from total_film_counts
order by customer_id asc

--------------------------------------------
--#7 Generate 1st category insight - create temp table top_1_category_insight
----customer_id 
----category_name
----rental_count 
----comparison = rental_count - avg_category_count
----percentile 
----proportion = rental_count
--------------------------------------------
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
-------Check temp table top_1_category_insight
select * from top_1_category_insight

--------------------------------------------
--#8 Generate 2nd category insight - create temp table top_2_category_insight
----category_name
----rental_count
----proportion
--------------------------------------------
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
-------Check temp table top_2_category_insight
select * from top_2_category_insight



--------------------------------------------
--------------------------------------------
--########## CATEGORY RECOMMENDATIONS ##########
--##############################################################
--------------------------------
--2 criterias:
--A rcm films are comprised in top 2 ranking categories
--B rcm films are poplar: (1)rental_count at top; (2) exclude customer+title watched


--#1  Generate a summarised film count table with the category included. Create temp table film_count
DROP TABLE IF EXISTS film_counts
select distinct 
    film_id,
    title,
    category_name,
    count(*)  over(partition by film_id) as film_count
into film_counts --create temp table film_counts
from completed_join_dataset
-------Check temp table film_count
select * from film_counts
select count(distinct category_name) from film_counts
select count(distinct category_name) from top_2_category


--#2 Create a previously watched films for the top 2 categories to exclude for each customer
DROP TABLE IF EXISTS category_film_exclusions;
select distinct 
    customer_id,
    film_id
into category_film_exclusions --create temp table category_film_exclusions
from completed_join_dataset
-------Check temp table category_film_exclusions
select * from category_film_exclusions

--#3 Create temp table final for category_recommendation
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
-------Check temp table category_film_exclusions
select * from category_recommendation
order by customer_id, category_ranking, film_ranking 



--------------------------------------------
--------------------------------------------
--########## TOP ACTOR & ACTOR INSIGHTS ##########
--##############################################################
----actor_name
----rental_actor_count

--#1 Create join temp table for actor dataset
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
-------Check temp table category_film_exclusions
select * from actor_film_dataset


--#2.1 Create temp table for actor_rental_count - Calculate the actor that customers watches
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
-------Check temp table actor_rental_counts
select * from actor_rental_counts

--#2.2 Create temp table for actor_rental_count - Calculate the actor that customers watches THE MOSTTT
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
-------Check temp table top_actor_rental_count
select * from top_actor_rental_count
order by customer_id


--------------------------------------------
--------------------------------------------
--########## ACTOR RECOMMENDATIONS ##########
--##############################################################
--criteria 1: top actor rental count
--criteria 2: popular: (1) top film popular of that actor, (2) exclude film of actor that customer watched

--#1 Create table count for all actor and all film 
--#2 Create exclusion table for customer, title, actor
--#3 Create table join for top 1 ranking actor with title, set ranking partition by customer and actor
--#4 create table anti join with exclusion table to find the final result table
--------------------------------------------------------


------#1 Create table count for all actor and all film 
DROP TABLE IF EXISTS total_actor_film_counts;
select distinct 
        title,
        full_name,
        count(*) OVER(partition by title, full_name) as total_actor_film_count
into total_actor_film_counts -- CREATE TEMP TABLE total_actor_film_counts
from actor_film_dataset

-------Check temp table total_actor_film_counts
select * from total_actor_film_counts



------#2 Create exclusion table for customer, title, actor
DROP TABLE IF EXISTS exclusion_actor_film;
select distinct
        customer_id,
        title,
        full_name
into exclusion_actor_film -- CREATE TEMP TABLE exclusion_actor_film
from actor_film_dataset
-------Check temp table exclusion_actor_film
select * from exclusion_actor_film


------#3 Create table join for top 1 ranking actor with title, set ranking partition by customer and actor
------#4 Create table anti join with exclusion table to find the final result table
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

-------Check temp table actor_film_recommendation
select * from actor_film_recommendation
