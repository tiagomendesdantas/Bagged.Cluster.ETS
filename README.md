# Bagged.Cluster.ETS
Method developed by Tiago Dantas and Fernando Cyrino Oliveira that combines Bagging, Clusters and ETS to produce highly accurate time series forecasts.

# The method:
Bagging Exponential Smoothing procedures have recently arisen as an innovative way to improve forecast accuracy. The idea is to use Bootstrap to generate multiple versions of the time series and, subsequently, apply an Exponential Smoothing (ETS) method to produce forecasts for each of them. The final result is obtained aggregating the forecasts. The main drawback of existing procedures is that Bagging itself does not avoid generating highly correlated ensembles that might affect the forecast error. Bagged.Cluster.ETS enhance existing Bagging Exponential Smoothing methods by an addition of a clustering phase. The general idea is to generate Bootstrapped versions of the series and use clusters to select series that are less similar among each other. The expectation is that this would reduce the covariance and, consequently, the forecast error.


- The Paper called "**Improving Time Series Forecasting: an Approach Combining Bootstrap Aggregation, Clusters and Exponential Smoothing**" describing the entire approach has been accepted for publication in the *International Journal of Forecasting*.

- This work can be seen as an extension of the work from Christoph Bergmeir, Rob Hyndman and José Benítez called "Bagging exponential smoothing methods using STL decomposition and Box–Cox transformation". Therefore, this code uses parts of the BaggedETS R function from the **forecast** package. 

- **Warning:** The code uses functions to make parallel computations (currently just working in unix based os).
