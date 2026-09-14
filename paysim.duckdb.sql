SELECT * 
FROM 'PaySim/PS_data.csv'
LIMIT 10;

SELECT COUNT(*) As total_transactions
FROM 'PaySim/PS_data.csv';

SELECT 
type, 
COUNT(*) As transaction_count,
ROUND(AVG(amount), 2) As average_amount,
ROUND(MIN(amount), 2) As min_amount,
ROUND(MAX(amount), 2) As max_amount,
ROUND(SUM(amount), 2) As total_amount
FROM 'PaySim/PS_data.csv'
GROUP BY type
ORDER BY total_amount DESC;

SELECT isFraud,
COUNT(*) AS transaction_count
FROM 'PaySim/PS_data.csv'
GROUP BY isFraud;
-- isFraud=0 6354407, isFraud=1 8213
-- class imbalance is evident as fraud rate (0.1293%) is very low.

-- Group step buckets to analyze fraud
SELECT
    CASE
        WHEN step < 50 THEN '0-49'
        WHEN step < 100 THEN '50-99'
        WHEN step < 150 THEN '100-149'
        WHEN step < 200 THEN '150-199'
        WHEN step < 250 THEN '200-249'
        WHEN step < 300 THEN '250-299'
        WHEN step < 350 THEN '300-349'
        WHEN step < 400 THEN '350-399'
        WHEN step < 450 THEN '400-449'
        WHEN step < 500 THEN '450-499'
        WHEN step < 550 THEN '500-549'
        WHEN step < 600 THEN '550-599'
        WHEN step < 650 THEN '600-649'
        WHEN step < 700 THEN '650-699'
        WHEN step < 750 THEN '700-749'
        ELSE '750+'
    END AS step_bucket,
    COUNT(*) AS transactions,
    SUM(isFraud) AS fraud_transactions,
    ROUND(100.0 * SUM(isFraud) / COUNT(*),4) AS fraud_rate
FROM 'PaySim/PS_data.csv'
GROUP BY step_bucket
ORDER BY
    MIN(step);
-- Despite substantial variation in the total number of transactions across time buckets, 
-- the number of fraudulent transactions remains relatively stable, with approximately 500–600 fraud cases in each 50-step bucket.

-- Type vs fraud
SELECT
type,
COUNT(*) AS total_transactions,
SUM(isFraud) AS fraud_transactions,
ROUND(100.0 * SUM(isFraud) / COUNT(*), 4) 
AS fraud_rate_percent
FROM 'PaySim/PS_data.csv'
GROUP BY type
ORDER BY fraud_rate_percent DESC;
-- Fraud occurred at TRANSFER and CASH_OUT transactions.

SELECT
    type,
    isFraud,
    COUNT(*) AS transaction_count,
    ROUND(AVG(amount), 2) AS avg_amount,
    ROUND(MIN(amount), 2) AS min_amount,
    ROUND(MAX(amount), 2) AS max_amount
FROM 'PaySim/PS_data.csv'
GROUP BY type, isFraud
ORDER BY type, isFraud;
-- Fraudulent TRANSFER and CASH_OUT transactions had higher average transaction amounts than their non-fraudulent counterparts.


-- NameOrig transaction history vs fraud
WITH origin_history AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY nameOrig
            ORDER BY step, type, amount, nameDest
        ) AS origin_transaction_number
    FROM 'PaySim/PS_data.csv'
)
SELECT
    type,
    CASE
        WHEN origin_transaction_number = 1
            THEN '1st transaction'
        WHEN origin_transaction_number = 2
            THEN '2nd transaction'
        WHEN origin_transaction_number = 3
            THEN '3rd transaction'
        ELSE '4+ transactions'
    END AS origin_history_bucket,
    COUNT(*) AS transactions,
    SUM(isFraud) AS fraud_transactions,
    ROUND(100.0 * SUM(isFraud) / COUNT(*),4) AS fraud_rate
FROM origin_history
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY
    type,
    origin_history_bucket
ORDER BY
    type,
    MIN(origin_transaction_number);
-- Origin accounts exhibit very limited transaction history in the PaySim dataset: 
-- most appear only once, while no origin account appears more than three times.


-- Fraud transactions preview
SELECT *
FROM 'PaySim/PS_data.csv'
WHERE isFraud = 1
LIMIT 50;
-- Most fraudulent transactions had newbalanceOrig=0.

-- Zero balance vs fraud
SELECT
    isFraud,
    COUNT(*) AS transaction_count,
    SUM(CASE WHEN newbalanceOrig = 0 THEN 1 ELSE 0 END) AS zero_balance_count,
    ROUND(100.0 * SUM(CASE WHEN newbalanceOrig = 0 THEN 1 ELSE 0 END) / COUNT(*),
        2) AS zero_balance_rate
FROM 'PaySim/PS_data.csv'
GROUP BY isFraud;
-- 98.05% fraudulent transactions had newbalanceOrig=0.
-- Zero ending balance is strongly associated with fraudulent transactions. 

SELECT
    newbalanceOrig = 0 AS zero_balance,
    COUNT(*) AS transactions,
    SUM(isFraud) AS fraud_transactions,
    ROUND(
        100.0 * SUM(isFraud) / COUNT(*),
        4
    ) AS fraud_rate
FROM 'PaySim/PS_data.csv'
GROUP BY zero_balance
ORDER BY fraud_rate DESC;
-- Only 0.2231% of all zero-balance transactions were fraudulent. This suggests that zero ending balance is a useful fraud risk indicator, but it should not be used as a standalone fraud detection rule.

-- Balance mismatch analysis
SELECT *
FROM (
    SELECT
        step,
        type,
        amount,
        nameOrig,
        oldbalanceOrg,
        newbalanceOrig,
        oldbalanceOrg - newbalanceOrig AS actual_change,
        ROUND(ABS(oldbalanceOrg - newbalanceOrig) - amount, 2) AS difference,
        nameDest,
        oldbalanceDest,
        newbalanceDest,
        isFraud
    FROM 'PaySim/PS_data.csv')
WHERE difference != 0
ORDER BY ABS(difference) DESC;
-- Some transactions had oldbalanceOrg - amount != newbalanceOrig.

-- Check balance mismatches vs fraud occurrence
SELECT
    isFraud,
    COUNT(*) AS transaction_count,
    SUM(CASE WHEN ROUND(ABS(oldbalanceOrg - newbalanceOrig) - amount, 2) != 0 THEN 1 ELSE 0
        END) AS balance_mismatch_count,
    ROUND(100.0 *SUM(CASE WHEN ROUND(ABS(oldbalanceOrg - newbalanceOrig) - amount, 2) != 0 THEN 1 ELSE 0
            END) / COUNT(*), 2) AS mismatch_rate
FROM 'PaySim/PS_data.csv'
GROUP BY isFraud;
-- Balance inconsistencies are not a reliable fraud indicator in PaySim. 
-- While 61.99% of non-fraudulent transactions exhibited a mismatch between the expected and recorded origin balance,
-- only 0.55% of fraudulent transactions show the same pattern.


-- Destination account transaction history
WITH destination_history AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY nameDest
            ORDER BY step,type,amount,nameOrig ) 
        AS destination_transaction_number
    FROM 'PaySim/PS_data.csv')
SELECT
    CASE
        WHEN destination_transaction_number = 1
            THEN '1st transaction'
        WHEN destination_transaction_number = 2
            THEN '2 transactions'
        WHEN destination_transaction_number = 3
            THEN '3 transactions'
        WHEN destination_transaction_number = 4
            THEN '4 transactions'
        WHEN destination_transaction_number = 5
            THEN '5 transactions'
        WHEN destination_transaction_number = 6
            THEN '6 transactions'
        WHEN destination_transaction_number <= 15
            THEN '7-15 transactions'
        ELSE '16+ transactions'
    END AS destination_history_bucket,
    COUNT(*) AS transactions,
    SUM(isFraud) AS fraud_transactions,
    ROUND(100.0 * SUM(isFraud) / COUNT(*),4) AS fraud_rate
FROM destination_history
GROUP BY destination_history_bucket
ORDER BY
    CASE destination_history_bucket
        WHEN '1st transaction' THEN 1
        WHEN '2 transactions' THEN 2
        WHEN '3 transactions' THEN 3
        WHEN '4 transactions' THEN 4
        WHEN '5 transactions' THEN 5
        WHEN '6 transactions' THEN 6
        WHEN '7-15 transactions' THEN 7
        WHEN '16+ transactions' THEN 8
    END;
-- Limited destination transaction history is associated with higher fraud risk.
-- Approximately 62.8% (5120/8213) of all fraudulent transactions involve a destination account appearing for the first time in the dataset.
-- Destination transaction history based on the observed transaction order in the dataset.

-- Destination account transactions amount
SELECT
    nameDest,
    type,
    COUNT(*) AS total_transactions,
    SUM(isFraud) AS fraud_transactions,
    COUNT(*) - SUM(isFraud) AS nonfraud_transactions,
    ROUND( AVG(CASE WHEN isFraud = 1 THEN amount END),2) AS fraud_avg_amount,
    ROUND(SUM(CASE WHEN isFraud = 0 THEN amount END),2) AS nonfraud_sum_amount,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 2) AS fraud_rate
FROM 'PaySim/PS_data.csv'
GROUP BY nameDest,type
HAVING SUM(isFraud) > 0
ORDER BY fraud_avg_amount DESC
Limit 50;
-- The $10 million transaction amount is strongly associated with fraudulent activity in the PaySim simulation.
-- Fraudulent TRANSFER destinations are often one-off destinations, 
-- whereas fraudulent CASH_OUT destinations can have multiple legitimate transactions associated with the same destination account.
-- Some fraudulent transactions involve destination accounts with very limited transaction histories.


-- Check the upper limit of transaction amounts
SELECT
    MAX(amount) AS max_amount
FROM 'PaySim/PS_data.csv';
-- A notable concentration of fraudulent transactions occurs at exactly $10 million. This appears to be a characteristic of the simulated fraud behavior rather than a transaction-size limit, since legitimate transactions can exceed $10 million and the dataset contains transactions as large as approximately $92.4 million.
SELECT
    COUNT(*) AS transactions_over_10m,
    SUM(isFraud) AS fraud_transactions,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 2) AS fraud_rate
FROM 'PaySim/PS_data.csv'
WHERE amount > 10000000;
--There are 2,443 transactions with amounts exceeding $10 million, and none of them were classified as fraudulent.

-- Transactions with exactly $10 million amount vs fraud
SELECT
    isFraud,
    COUNT(*) AS transaction_count,
    ROUND(AVG(amount), 2) AS avg_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount
FROM 'PaySim/PS_data.csv'
WHERE amount = 10000000
GROUP BY isFraud;
-- $10M transactions have a substantially higher fraud rate than the overall dataset.

-- Amount of $10 million distribution by type
SELECT
    type,
    isFraud,
    COUNT(*) AS transaction_count
FROM 'PaySim/PS_data.csv'
WHERE amount = 10000000
GROUP BY type, isFraud
ORDER BY type, isFraud DESC;
-- The fraudulent transactions were almost evenly split between the Transfer and Cash_Out types.



-- Top 20 most frequent fraudulent transaction amounts
SELECT
    amount,
    COUNT(*) AS fraud_count
FROM 'PaySim/PS_data.csv'
WHERE isFraud = 1
GROUP BY amount
ORDER BY fraud_count DESC
LIMIT 20;
-- Interestingly, 16 transactions classified as fraudulent have an amount of $0.

-- Check the 16 fraudulent transactions with zero amount.
SELECT
    step,
    type,
    amount,
    nameOrig,
    oldbalanceOrg,
    newbalanceOrig,
    nameDest,
    oldbalanceDest,
    newbalanceDest,
    isFraud,
    isFlaggedFraud
FROM 'PaySim/PS_data.csv'
WHERE isFraud = 1
  AND amount = 0
ORDER BY type, step;
-- PaySim contains 16 transactions, not classified as isFlaggedFraud but labeled as fraudulent despite having zero transaction amounts and no apparent movement of funds.

-- isFlaggedFraud indicator vs fraud
SELECT
    isFlaggedFraud,
    COUNT(*) AS transaction_count,
    SUM(isFraud) AS fraud_transactions,
    ROUND(100.0 * SUM(isFraud) / COUNT(*),4) AS fraud_rate
FROM 'PaySim/PS_data.csv'
GROUP BY isFlaggedFraud
ORDER BY isFlaggedFraud DESC;
-- All 16 transactions flagged by the existing fraud detection mechanism were actually fraudulent.
-- The isFlaggedFraud indicator achieves perfect precision, but extremely low recall.

-- Avg amount/oldbalanceOrg vs fraud
SELECT
    isFraud,
    ROUND(AVG(CASE WHEN oldbalanceOrg > 0
        THEN amount / oldbalanceOrg END),4) 
        AS avg_amount_to_balance_ratio
FROM 'PaySim/PS_data.csv'
GROUP BY isFraud;
-- On average, the transaction amount of fraudulent is close to the origin account's existing balance.
-- This finding is consistent with the earlier observation that 98.05% of fraudulent transactions resulted in a zero newbalanceOrig.

-- Exceeding balance ratio vs fraud
SELECT
    isFraud,
    COUNT(*) AS transactions,
    SUM(CASE WHEN amount > oldbalanceOrg THEN 1 ELSE 0 END)
        AS amount_exceeds_balance,
    ROUND(100.0 * SUM(
            CASE WHEN amount > oldbalanceOrg THEN 1 ELSE 0 END
        ) / COUNT(*),4) 
        AS exceeds_balance_rate
FROM 'PaySim/PS_data.csv'
WHERE type IN ('TRANSFER', 'CASH_OUT', 'PAYMENT')
  AND oldbalanceOrg > 0
GROUP BY isFraud;
-- Fraudulent transactions almost never have an amount exceeding the origin account's existing balance, 
-- whereas this occurs in more than half of non-fraudulent transactions.

-- grouped amount/oldbalanceOrg bucket to analyze fraud
SELECT
    CASE
        WHEN amount / oldbalanceOrg < 0.90
            THEN '75%-<90%'
        WHEN amount / oldbalanceOrg < 1.00
            THEN '90%-<100%'
        WHEN amount = oldbalanceOrg
            THEN '100%'        ELSE '>100%'
    END AS balance_ratio_bucket,
    COUNT(*) AS transactions,
    SUM(isFraud) AS fraud_transactions,
    ROUND(100.0 * SUM(isFraud) / COUNT(*),4) AS fraud_rate
FROM 'PaySim/PS_data.csv'
WHERE type IN ('TRANSFER', 'CASH_OUT', 'PAYMENT')
  AND oldbalanceOrg > 0
  AND amount >= oldbalanceOrg * 0.75
GROUP BY balance_ratio_bucket
ORDER BY
    CASE balance_ratio_bucket
        WHEN '75%-<90%' THEN 1
        WHEN '90%-<100%' THEN 2
        WHEN '100%' THEN 3
        ELSE 4
    END;
-- 97.63% of all fraudulent transactions occur when the transaction amount exactly matches the origin account's recorded balance (oldbalanceOrg).

-- Combine exact balance depletion and $10M amount patterns to analyze their joint impact on fraud.
SELECT
    CASE
        WHEN amount = oldbalanceOrg
             AND amount = 10000000
            THEN 'Both: Exact balance + $10M'
        WHEN amount = oldbalanceOrg
            THEN 'Exact balance only'
        WHEN amount = 10000000
            THEN '$10M only' 
        ELSE 'Neither'
    END AS fraud_pattern,
    COUNT(*) AS transactions,
    SUM(isFraud) AS fraud_transactions,
    ROUND(100.0 * SUM(isFraud) / COUNT(*),4) AS fraud_rate
FROM 'PaySim/PS_data.csv'
GROUP BY fraud_pattern
ORDER BY fraud_rate DESC;
-- The $10M amount is a secondary fraud-associated pattern.
-- Exact balance depletion (amount = oldbalanceOrg) is the strongest
-- fraud-associated pattern observed in the PaySim dataset.
-- It accounts for approximately 97.82% of fraudulent transactions
-- and shows a 100% fraud rate within this dataset.
--
-- However, this relationship may reflect the synthetic fraud-generation
-- rules used by PaySim and should not be assumed to generalize to
-- real-world fraud detection.
