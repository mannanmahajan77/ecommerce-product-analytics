# E-commerce Product Analytics

## Project Overview

Two years of transactions from a UK online gift retailer. 1.07 million rows, December 2009 to December 2011, covering 5,839 identified customers and £16.8m of revenue.

The project answers three questions a product analyst would actually be handed: where the revenue comes from, which customers are worth keeping, and what specific change would raise average order value.

There is no model in here on purpose. The output is a bundle recommendation with a revenue estimate and a diagnosis of a revenue dip that turned out to be nothing.

**Data:** [Online Retail II, UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/502/online+retail+ii)

---

## What The Project Covers

* **Cleaning with a decision log.** Every removal recorded with its row count and revenue impact. 96.5% of rows retained.
* **Core business metrics.** Revenue, orders, AOV, active customers by month, revenue concentration, new versus returning split.
* **Cohort retention.** Customer count and revenue matrices by months since first purchase, plus heatmaps and curves.
* **RFM segmentation.** Recency, frequency and monetary scored into quintiles, five named segments, each sized by revenue and given an action.
* **Market basket analysis.** Support, confidence and lift computed from hand-rolled pair counts across 558,778 product pairs.
* **Root cause analysis.** A full decomposition of the April 2011 revenue drop, from metric arithmetic down to individual accounts.
* **SQL layer.** Seven queries in MySQL covering the same analyses, including cohort retention in pure window functions.

---

## Findings

**1. Acquisition halved and revenue did not move.**

New customers fell from roughly 290 a month in 2010 to 130 in 2011. Revenue stayed flat year on year: November 2010 was £1.131m, November 2011 was £1.129m. The existing base absorbed the entire drop.

**2. That works because churn is concentrated in low-value customers.**

In every large cohort, revenue retention runs above customer retention. Around 30% of customers return, and they bring back 35% to 45% of what the whole cohort spent in its first month. The customers who leave were the small ones, which is why losing half the acquisition rate cost so little.

**3. Revenue is extremely concentrated.**

58 customers, the top 1%, account for 31% of revenue. The top 10% account for 63%. Mean revenue per customer is £2,883 against a median near £875, so the mean is not a usable figure for anything.

**4. The monthly reporting window is wrong for this business.**

Month 1 retention is *lower* than months 2, 3 and 4 in almost every cohort. Only 31% of returning customers come back inside 30 days, and 27% take longer than 90. These are wholesale buyers restocking every couple of months, so a monthly window marks them churned while they are behaving normally. Churn here should be defined at 90 days.

**5. April 2011 looked like a 22% collapse and was not one.**

Orders fell 13%, basket size held flat, price per unit fell 7%. By country, the UK carried only 46% of the loss despite being 92% of the business, while the export markets stopped rather than softened. Two accounts explain £35,168 of the £127,624 gap, and both ordered normally again in May. Two wholesale customers happened to skip the same month.

---

## Recommendation

Bundle the Regency range around the 3-tier cakestand.

* 3,039 cakestand buyers never purchased the Regency teapot, despite a lift of 5.25 between the two products.
* 72.6% of Regency sugar bowl buyers take the milk jug, so the range already cross-sells well between its smaller pieces.
* The gap sits at the hero product. The cakestand brings people into the range and then sells them nothing else.
* At 15% conversion, the top ten cross-sell pairs are worth £167,167, roughly 1% of revenue. At 5% it is £56k, at 25% it is £278k.

The 15% is an estimate, not a measurement, since the bundle has never been offered and nothing in the data can produce that rate. The way to settle it is to ship the bundle to half the catalogue and track cakestand-attached revenue for a quarter against the same period a year earlier.

---

## Notes On The Data

* **The return rate was wrong before cleaning.** It looked like 7.3% by value until the non-product StockCodes came out. Postage, Amazon fees and a £148k bad debt write-off were sitting inside it. The real rate is 3.6%.
* **Cancellations need both sides removed.** Deleting the negative rows alone leaves the original purchase in place, so a customer who ordered 80,995 units and cancelled minutes later becomes the largest account in the book. Matching returns to purchases on customer, SKU and quantity caught 37% by count but 78% by value.
* **22.7% of rows have no customer ID.** Those invoices average 80 line items each, which is not a normal order, so they are excluded from anything order-level and kept only in total revenue.
* **Lift alone does not produce a recommendation.** Ranking basket rules by lift returned twenty colour variants of the same products. Ranking by revenue opportunity returned the cakestand. Lift qualifies a rule as non-random. Something else has to rank it commercially.

---

## Technical Stack

* **Analysis:** Python (Pandas, NumPy, Matplotlib, Seaborn), run in Google Colab
* **Database:** MySQL, loaded via SQLAlchemy, queried in Workbench
* **SQL used:** CTEs, window functions (NTILE, RANK, DENSE_RANK, LAG, ROW_NUMBER with PARTITION BY), conditional-aggregation pivots, self-joins
* **Market basket:** hand-rolled pair counting with itertools and collections.Counter rather than mlxtend
* **Version control:** Git and GitHub

---

## Repository Structure

```
ecommerce_analysis.ipynb    cleaning through market basket
analysis_queries.sql        seven queries, MySQL
monthly_trend.png
cohort_retention.png
revenue_retention.png
retention_curves.png
requirements.txt
```

The raw dataset is not included. It is 91MB and available at the UCI link above.
