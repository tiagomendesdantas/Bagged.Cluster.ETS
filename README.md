# Bagged.Cluster.ETS
Method developed by Tiago Dantas and Fernando Cyrino Oliveira that combines Bagging, Clusters and ETS to produce highly accurate time series forecasts.

- The Paper called "**Improving Time Series Forecasting: an Approach Combining Bootstrap Aggregation, Clusters and Exponential Smoothing**" describing the entire approach has been accepted for publication in the *International Journal of Forecasting*.

- This work can be seen as an extension of the work from Christoph Bergmeir, Rob Hyndman and José Benítez called "Bagging exponential smoothing methods using STL decomposition and Box–Cox transformation". Therefore, this code uses parts of the BaggedETS R function from the **forecast** package. 

- **Warning:** The code use functions to make parallel computations (currently just working in unix based os).
