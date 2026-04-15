Principal questions to solve

* How much are we selling?
* Is revenue growing or shrinking over time?
* Which categories drive revenue?
* Which products drive revenue?
* Which sellers drive revenue?
* Which states or cities drive revenue?
* Which customers or customer segments are most valuable?
* How many orders are we getting?
* What is the average order value?
* What is the average item price?
* How much of revenue is freight?
* Which categories have the highest freight burden?
* Which sellers have the highest freight burden?
* Which order statuses are increasing?
* How many orders are canceled, delivered, shipped, or delayed?
* Which categories or sellers have the worst order status mix?
* Which periods have unusual spikes or drops?
* Which dimensions explain those spikes or drops?
* Which products are bulky, heavy, or inefficient to ship?
* Which combinations of category, state, and seller perform best or worst?

Most useful charts for BI exploratory analysis

Core health

* KPI cards

  * revenue
  * order count
  * item count
  * average order value
  * average freight
* Line chart

  * revenue by day, week, month
* Line chart

  * orders by day, week, month
* Combo line and bar

  * revenue and order count over time

Mix and composition

* Horizontal bar chart

  * revenue by category
* Horizontal bar chart

  * revenue by seller
* Horizontal bar chart

  * revenue by state
* Stacked bar chart

  * order status by month
* Treemap

  * revenue share by category or seller
* Donut or stacked bar

  * revenue share by order status or payment type

Efficiency and operations

* Scatter plot

  * freight value versus item price
* Scatter plot

  * product weight versus freight value
* Scatter plot

  * product volume versus freight value
* Box plot

  * freight by category
* Box plot

  * order value by state or seller
* Heatmap

  * category versus state by revenue
* Heatmap

  * seller versus order status by count

Ranking and concentration

* Top N bar chart

  * top products by revenue
* Top N bar chart

  * top sellers by revenue
* Pareto chart

  * cumulative revenue by top sellers or top categories
* Ranked table

  * categories with revenue, order count, average ticket, freight ratio

Time intelligence

* Month-over-month bar chart

  * revenue growth
* Rolling average line

  * revenue trend smoothing
* Calendar heatmap

  * orders or revenue by day
* Day-of-week bar chart

  * order count or revenue by weekday
* Hour-of-day bar chart if timestamp granularity exists

  * order activity by hour

Data quality and anomaly finding

* Null or missing-value table

  * missing dimension keys or attributes
* Distribution histogram

  * order value
* Distribution histogram

  * freight value
* Distribution histogram

  * product weight
* Outlier scatter plot

  * very high freight or very high item price
* Control chart or anomaly line

  * daily revenue with deviations

Best first dashboard

* KPI cards:

  * total revenue
  * total orders
  * average order value
  * freight ratio
* Line chart:

  * revenue by month
* Bar chart:

  * revenue by category
* Bar chart:

  * revenue by state
* Bar chart:

  * top sellers by revenue
* Stacked bar:

  * order status by month
* Scatter:

  * freight versus item price

Best exploratory filters

* date range
* category
* seller
* state
* order status
* payment type

Metric list to define once

* gross revenue = sum(item_price)
* freight revenue = sum(freight_value)
* total revenue = sum(item_price + freight_value)
* order count = count(distinct order_id)
* item count = count(*)
* average order value = total revenue / order count
* average item price = sum(item_price) / item count
* freight ratio = sum(freight_value) / sum(item_price + freight_value)


