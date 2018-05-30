# The objective of this project is to develop
# a predictive model that would identify dissatisfied
# customers of Santander. This is key for customer
# retenstion as well as business growth.


# # The dataset used  for this demonstration was extracted from the url:
# https://www.kaggle.com/c/santander-customer-satisfaction
# and can be found in the dataset folder of this Github page.

# The analytics tool of choice for this project is R.


# Download the required R packages

library(caret)              #  required for cross validation
library(xgboost)            #  required for building boosting model
library(mlr)                #  required for descriptive statistics
'%ni%' <- Negate('%in%')    #  syntax to exclude data fields


# Importing the dataset
raw_data <- read.csv(file.choose(), header = T)

# Run a descriptive statistics on the dataset
summarizeColumns(raw_data)

# from the output of the above code,
# a feature (var3) does have missing number -999999.00
# this will be taken intp consideration in the building phase of the model

# View the structure of the dataset
str(raw_data)


# Remove the Id field as it does not have a meeting
# in the modeling phase
raw_data <- raw_data[,-1]


# Note: I have decided to split the original training set so as to have
# a model with Labels to test the accuracy of the built model as the original
# test set does not have labels.

# Splitting the imported dataset into Training and Test sets,
# allocating 70% to training set and the reaminder to test set
# using the createDataPartition() from caret package

trainRows <- createDataPartition(raw_data$TARGET,p=.7,list=FALSE)
trainData <- raw_data[trainRows, ]
testData  <- raw_data[-trainRows, ]

# Check class imbalance
table(trainData$TARGET)

# The output show a significant imbalance of our label
# This will also be put into considration in the model building process
# by way of introducing a weigth parameter which is now calculated below.
neg_class <- sum(trainData$TARGET == 0)
pos_class <-  sum(trainData$TARGET == 1)
weight<- neg_class/pos_class


# Fitting an initial xgboost model to the Training dataset
data <- as.matrix(trainData[, colnames(trainData) %ni% "TARGET"]) # define the input features
label <- trainData$TARGET                                         # define the label or response variable

classifier <- xgboost(data = data, 
                     eval_metric = "auc",label = label, 
                     "objective" = "binary:logistic", 
                     early_stopping_rounds = 4,
                     scale_pos_weight = weight,
                     missing = -999999.00,
                     "nthread" = 4, nrounds = 10)

#  make prediction on the test data set
tdata <- as.matrix(testData[, colnames(testData) %ni% "TARGET"]) # define the input features

y_pred <-  predict(classifier, newdata = tdata)

# Making a Confusion Matrix
y_pred <-  (y_pred >= 0.5)
cm <- table(testData$TARGET, y_pred)
cm 

# With the above accuracy as a benchmark,
# cross validation is now applied to the training set
# to reduce overfiting.

folds <- createFolds(trainData$TARGET, k = 10)

cv <- lapply(folds, function(x) {
      training_fold = trainData[-x, ]
      test_fold = trainData[x, ]
      classifier = xgboost(data = as.matrix(trainData[, colnames(trainData) %ni% "TARGET"]),
                           label = trainData$TARGET, 
                           eval_metric = "auc",
                           "objective" = "binary:logistic",
                           early_stopping_rounds = 4,
                           "nthread" = 4,
                            scale_pos_weight = weight,nrounds = 100)
      
      # prediction on the test data set.
      y_pred = predict(classifier, newdata = as.matrix(testData[, colnames(testData) %ni% "TARGET"]))
      y_pred = (y_pred >= 0.5)
      cm = table(testData$TARGET, y_pred)
      accuracy = (cm[1,1] + cm[2,2]) / (cm[1,1] + cm[2,2] + cm[1,2] + cm[2,1])
      return(accuracy)
})
accuracy = mean(as.numeric(cv))
# accuracy of 0.8364027


# We now import the original test dataset(downloaded from the kaggle website)
original_test_data <- read.csv(file.choose(), header = T)

# assign the Id field to the ID object, this will be required
# when we will write our results to Excel file
ID <- original_test_data[1]

# we also assign the every other feature except the Id field to
# the test_data_without_id  object.
test_data_without_id <- original_test_data[,-1]

# make prediction on the Original dataset
y_pred = predict(classifier, newdata = as.matrix(test_data_without_id))

# Convert the probabilies to 1 or 0 given the condition below
plabel = ifelse(y_pred > 0.5, 1, 0)

# list the required data to be written to file
outdata = list("ID" = ID,"TARGET" = plabel)

# write the prediction according to the required format.
write.csv(outdata, file = "submission.csv", quote=FALSE, row.names=FALSE)
