#### **Model Development, Evaluation, and Threshold Selection Report**

**1. Project Objective**

The objective of this project was to develop and evaluate a machine learning model for identifying transactions labeled as potentially related to money laundering. Beyond predictive performance, I focused on understanding transaction behavior, engineering historical behavioral features, and evaluating how classification thresholds affect detection performance and investigation workload.

Dataset: IBM Transactions for Anti-Money Laundering (AML), HI-Small
Primary analysis period: September 1–10, 2022
Model: XGBoost Classifier

**2. Data Quality Assessment and Exploratory Data Analysis**

**2.1 Data Quality and Data Suitability**

I first assessed data quality, including missing values and duplicate records, to determine which data was suitable for analysis. I also reviewed transaction volume and positive-label distributions over time to select an appropriate period for modeling.

The dataset showed substantial changes in transaction volume and positive-label rates across different periods. I therefore selected September 1–10 as my primary modeling period rather than combining periods with significantly different distributions.

**2.2 Exploratory Data Analysis**

I explored the original transaction variables and their relationships with the dataset's positive labels, focusing on:

Transaction amounts: Examined distributions and identified substantial right skewness and extreme values.

Payment formats: Observed differences in positive-label rates across transaction formats. ACH transactions accounted for approximately 84.65% of positive labels in the selected period.

Currencies: Examined currency patterns and relationships with transaction amounts and labels.

Account activity: Investigated transaction concentration and historical activity across sender accounts.

Temporal patterns: Examined transaction frequency and activity over different time periods.

The analysis suggested that individual transaction attributes alone might not fully capture suspicious behavior. This motivated the development of historical behavioral features.

**3. Feature Engineering**

My main objective in feature engineering was to represent transaction behavior mathematically, going beyond the characteristics of an individual transaction.

**3.1 Historical Account Behavior**

I developed features to capture account activity and transaction relationships:

sender_transaction_count: Historical transaction count for the sender.

sender_unique_receivers: Number of distinct receivers previously associated with the sender.

receiver_transaction_count: Historical transaction count for the receiver.

receiver_unique_senders: Number of distinct senders previously associated with the receiver.

**3.2 Short-Term Transaction Behavior**

I also engineered rolling one-hour features to capture changes in transaction activity:

sender_1h_frequency: Number of transactions initiated by the sender during the preceding hour.

sender_1h_total_paid: Total payment amount initiated by the sender during the preceding hour.

These features were calculated using prior transactions only, excluding the current transaction and transactions with the same timestamp, to avoid look-ahead bias.

**3.3 Additional Feature Preparation**

I applied a logarithmic transformation to transaction amounts to reduce the impact of extreme values.

I also extracted temporal features, including transaction hour, day, and weekday.

For categorical variables, such as Payment Format and Receiving Currency, I used One-Hot Encoding to create binary indicator features.

The final feature set included 10 numerical predictors and 2 categorical predictors. Raw account identifiers were excluded from the model.

**4. Model Development**

I selected XGBoost as the classification model and used a chronological training and testing split to better reflect a time-based transaction monitoring scenario.

| Dataset | Transactions | Positive Labels |
|---|---:|---:|
| Training | 4,214,445 | 3,566 |
| Testing | 862,792 | 956 |

The positive class represented a very small proportion of the transactions, creating a severe class imbalance.

To address this, I used the scale_pos_weight parameter in XGBoost. The weight was initialized using the ratio of negative to positive observations in the training data.

I also used One-Hot Encoding for categorical variables and configured the encoder to handle previously unseen categories.

**5. Model Evaluation and Diagnostics**

Given the severe class imbalance, I focused on PR-AUC, precision, recall, and false positive rate rather than relying on accuracy alone.

At the initial classification threshold of 0.5, the model achieved the following results:

| Metric | Result |
|---|---:|
| PR-AUC | 0.3239 |
| Precision | 1.74% |
| Recall | 87.45% |
| False Positive Rate | 5.48% |
| Alert Volume | 48,041 |

The confusion matrix was:

| | Predicted Negative | Predicted Positive |
|---|---:|---:|
| Actual Negative | 814,631 | 47,205 |
| Actual Positive | 120 | 836 |

The model identified approximately 87.45% of the positive labels, but it also generated a substantial number of false positives. This highlighted the need to evaluate different classification thresholds to manage investigation workload.

** Feature Importance Analysis**

I examined XGBoost feature importance to understand which predictors contributed most to the model.

Payment Format, particularly the ACH category, had the largest feature importance. This was consistent with the patterns observed during EDA.

However, feature importance indicates predictive contribution within the fitted model; it does not establish causation or prove that a particular transaction format represents higher real-world money laundering risk.

I also conducted a feature sensitivity experiment by removing Payment Format and retraining the model. PR-AUC decreased from 0.3239 to 0.2015, while recall remained almost unchanged. This demonstrated the model's substantial reliance on Payment Format in this dataset.

**6. Threshold Sensitivity Analysis**

Because the default classification threshold of 0.5 generated a large number of alerts, I evaluated different thresholds to understand the trade-off between detection performance and investigation workload. I evaluated classification thresholds ranging from 0.1 to 0.9 to understand their impact on detection performance and alert volume.

| Threshold | Precision | Recall | Alert Volume | FPR |
|---:|---:|---:|---:|---:|
| 0.1 | 0.81% | 95.61% | 112,487 | 12.95% |
| 0.2 | 1.00% | 92.57% | 88,414 | 10.16% |
| 0.3 | 1.19% | 90.48% | 72,419 | 8.30% |
| 0.4 | 1.43% | 88.81% | 59,420 | 6.80% |
| 0.5 | 1.74% | 87.45% | 48,041 | 5.48% |
| 0.6 | 2.16% | 85.88% | 38,081 | 4.32% |
| 0.7 | 2.59% | 84.00% | 31,046 | 3.51% |
| 0.8 | 3.25% | 82.43% | 24,257 | 2.72% |
| 0.9 | 4.45% | 78.45% | 16,844 | 1.87% |

The results showed a trade-off between detection performance and investigation workload. As the threshold increased, precision improved and alert volume decreased, while recall also declined.

**7. Threshold Selection Rationale**

To connect model evaluation with operational considerations, I introduced two hypothetical business constraints:

- Maximum investigation capacity: 25,000 alerts.
- Minimum recall requirement: 80%.

Based on these assumptions, I compared the candidate thresholds.

At a threshold of 0.5, the model generated 48,041 alerts, exceeding the assumed investigation capacity.

At a threshold of 0.8, the alert volume decreased to 24,257, while recall remained at 82.43%. Both hypothetical requirements were satisfied.

At a threshold of 0.9, alert volume decreased further to 16,844, but recall fell to 78.45%, below the assumed minimum requirement.

Therefore, 0.8 was selected as a candidate threshold under these hypothetical operational constraints.

**8. Limitations and Considerations**

Several limitations should be considered when interpreting the results:

**Synthetic dataset:**
The positive labels are dataset-provided labels and should not be interpreted as independently verified money laundering cases.

**Temporal distribution shifts:**
The dataset exhibited substantial changes in transaction volume and positive-label rates across different periods.

**Feature dependence:**
Payment Format had a dominant influence on model predictions, potentially reflecting dataset-specific label patterns.

**Currency comparability:**
The rolling one-hour cumulative payment amount was calculated using raw nominal amounts without foreign exchange normalization.

**Threshold assumptions:**
The investigation capacity of 25,000 alerts and minimum recall target of 80% were hypothetical assumptions, not actual operational requirements.

**Threshold validation:**
The threshold comparison and candidate selection were exploratory analyses conducted on the same test set. The selected threshold would require further validation on an independent dataset or subsequent time period before operational deployment.

**9. Conclusion**

This project covered the end-to-end analytical process of AML transaction monitoring, from data quality assessment and exploratory analysis to behavioral feature engineering, model development, model evaluation, and threshold selection.

My main focus was to combine quantitative modeling with practical decision-making. By translating historical transaction behavior into measurable features and evaluating threshold trade-offs under hypothetical operational constraints, I demonstrated how statistical analysis can support both risk detection and investigation resource management.
