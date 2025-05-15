-- Dataset I:D bqml_lab
-- Table Data: training_data

-- QUESTIONS:
-- What is Training Data Loss
-- Evaluation Data Loss
-- Learn Rate

-- The data tables have a lot of columns, but there are few of interest to us that we will use to create our ML model.
-- Here the visitor's device's operating system is used, whether said device is a mobile device, the visitor's country or region and the number of page views will be used as the criteria for whether a transaction has been made.
-- In this case, label is what you're trying to fit to (or predict).
-- This data will be the training data for the ML model you create. The training data is being limited to those collected from 1 August 2016 to 31 June 2017.
-- This is done to save the last month of data for "prediction". It is further limited to 10,000 data points to save some time.
#standardSQL
CREATE OR REPLACE VIEW `gcp-vi-s-mlops.bqml_lab_us.training_data` AS
SELECT
  IF(totals.transactions IS NULL, 0, 1) AS label,
  IFNULL(device.operatingSystem, "") AS os,
  device.isMobile AS is_mobile,
  IFNULL(geoNetwork.country, "") AS country,
  IFNULL(totals.pageviews, 0) AS pageviews
FROM
  `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20160801' AND '20170631'
LIMIT 10000;

#standardSQL
CREATE OR REPLACE VIEW `gcp-vi-s-mlops.bqml_lab_us.training_data_full` AS
SELECT
  *
FROM
  `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20160801' AND '20170631';

-- CREATE A MODEL
-- Now replace the query with the following to create a model to predict whether a visitor will make a transaction:
#standardSQL
CREATE OR REPLACE MODEL `bqml_lab_us.sample_model`
OPTIONS(model_type='logistic_reg') AS
SELECT * from `bqml_lab_us.training_data`;
-- In this case, bqml_lab is the name of the dataset, sample_model is the name of the model, training_data is the transactions data we looked at in the previous task.
-- The model type specified is binary logistic regression.
-- Running the CREATE MODEL command creates a Query Job that will run asynchronously so you can, for example, close or refresh the BigQuery UI window.

-- Does not work because
-- Training is not supported for datatype STRUCT<campaignId INT64, adGroupId INT64, creativeId INT64, ...> for column 'trafficSource.adwordsClickInfo' in query statement.
-- #standardSQL
-- CREATE OR REPLACE MODEL `bqml_lab_us.sample_model_full`
-- OPTIONS(model_type='logistic_reg') AS
-- SELECT * from `bqml_lab_us.training_data_full`;

-- Evaluate the Model
#standardSQL
SELECT
  *
FROM
  ml.EVALUATE(MODEL `bqml_lab_us.sample_model`);
-- In this query, you use the ml.EVALUATE function to evaluate the predicted values against the actual data, and it shares some metrics of how the model performed.


-- Use the model
#standardSQL
CREATE OR REPLACE VIEW `gcp-vi-s-mlops.bqml_lab_us.july_data` AS
SELECT
  IF(totals.transactions IS NULL, 0, 1) AS label,
  IFNULL(device.operatingSystem, "") AS os,
  device.isMobile AS is_mobile,
  IFNULL(geoNetwork.country, "") AS country,
  IFNULL(totals.pageviews, 0) AS pageviews,
  fullVisitorId
FROM
  `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20170701' AND '20170801';
-- You'll realize the SELECT and FROM portions of the query is similar to that used to generate training data.
-- There is the additional fullVisitorId column which you will use for predicting transactions by individual user.The WHERE portion reflects the change in time frame (July 1 to August 1 2017).
-- Save as view july_data

-- With this query you will try to predict the number of transactions made by visitors of each country or region, sort the results, and select the top 10 by purchases:
#standardSQL
SELECT
  country,
  SUM(predicted_label) as total_predicted_purchases
FROM
  ml.PREDICT(MODEL `bqml_lab_us.sample_model`, (
SELECT * FROM `bqml_lab_us.july_data`))
GROUP BY country
ORDER BY total_predicted_purchases DESC
LIMIT 10;
-- In this query, you're using ml.PREDICT and the BigQuery ML portion of the query is wrapped with standard SQL commands.
-- For this lab you''re interested in the country and the sum of purchases for each country, so that's why SELECT, GROUP BY and ORDER BY. LIMIT is used to ensure you only get the top 10 results.

-- Here is another example. This time you will try to predict the number of transactions each visitor makes, sort the results, and select the top 10 visitors by transactions:
#standardSQL
SELECT
  fullVisitorId,
  SUM(predicted_label) as total_predicted_purchases
FROM
  ml.PREDICT(MODEL `bqml_lab.sample_model`, (
SELECT * FROM `bqml_lab_us.july_data`))
GROUP BY fullVisitorId
ORDER BY total_predicted_purchases DESC
LIMIT 10;
