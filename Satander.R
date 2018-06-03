library(mlr)
library(h2o)
h2o.init(nthreads = -1)

# Importing the dataset
raw_data <- read.csv(file.choose(), header = T)


# Run a descriptive statistics on the dataset
summarizeColumns(raw_data)

# from the output of the above code,
# a feature (var3) does have missing number -999999.00
# this will be taken into consideration in the building phase of the model

# check for missing values
sapply(raw_data, function(x) sum(is.na(x) >1))

# View the structure of the dataset
str(raw_data)

# Remove the Id field as it does not have a meaning in the modeling phase
raw_data <- raw_data[,-1]

# convert the label to character elements for clearity
raw_data$TARGET <- ifelse(raw_data$TARGET == 1, "Unsatisfied","Satisfied")

# convert the label (TARGET) to a factor as required by the model
raw_data[, "TARGET"] <- as.factor(raw_data[, "TARGET"])


# check for overall class imbalance in the imported dataset
table(raw_data$TARGET)

# split the data into training, validation and testing and convert to h2o data frame format
split_index <- sample(1:3, size = nrow(raw_data), replace = TRUE, prob = c(0.7,0.15,0.15))
train_h2o <- as.h2o(raw_data[split_index == 1, ])
valid_h2o <- as.h2o(raw_data[split_index == 2, ])
test_h2o <- as.h2o(raw_data[split_index == 3, ])

# inspect the dimension of the splits
dim(train_h2o)
dim(valid_h2o)
dim(test_h2o)

# check how imbalance the splits labels are.
# since there is significant imbalance, we would flag this up in the modeling process
table(as.data.frame(train_h2o$TARGET))
table(as.data.frame(valid_h2o$TARGET))
table(as.data.frame(test_h2o$TARGET))

# deeplearning model building phase
model <- h2o.deeplearning(x = 1:369,
                          y = 370,
                          training_frame = train_h2o,
                          activation = "TanhWithDropout",
                          distribution = "bernoulli",
                          input_dropout_ratio = 0.2,
                          balance_classes = TRUE,
                          hidden_dropout_ratios = c(0.5, 0.5, 0.5),
                          hidden = c(50, 50,50),
                          variable_importances = TRUE,
                          epochs = 10,
                          seed = 101)
 
# evaluate the model by viewing the confusion matrix to see how our initial model performed.
# the model is approximately 70% correct, we will use this accuracy as 
# a bench mark score, when we do a grid search
h2o.confusionMatrix(model, valid_h2o)
h2o.confusionMatrix(model, test_h2o)


# define hyper parameters for gridserach
hyper_params <- list(activation = c("Rectifier","Tanh","Maxout",
                                    "RectifierWithDropout","TanhWithDropout",
                                    "MaxoutWithDropout"),
                                    hidden = list(c(20,20),c(50,50),c(30,30,30),c(25,25,25,25),c(200,200),c(50,50,50)),
                                    distribution = "bernoulli",
                                    l1 = seq(0, 1e-4,1e-6),
                                    l2 = seq(0, 1e-4,1e-6))

# Define the search criteria parameters
search_criteria <- list(strategy = "RandomDiscrete", max_runtime_secs = 360,
                        max_models = 100, seed = 104, stopping_rounds = 5,
                        stopping_tolerance = 1e-2)

# build a more robost model which will generate optimal model given all the criteria listed above
deeplearning_random_grid <- h2o.grid(algorithm = "deeplearning",
                                     grid_id = "santander",
                                     training_frame = train_h2o,
                                     validation_frame = valid_h2o,
                                     x = 1:369,
                                     y = 370,
                                     epochs = 10,
                                     stopping_metric = "logloss",
                                     hyper_params = hyper_params,
                                     balance_classes = TRUE,
                                     search_criteria = search_criteria)

# sort the models based on the lowest logloss value
grid <- h2o.getGrid("santander", sort_by = "logloss",decreasing = FALSE)

# view the summary table of the models sorted by lowest logloss
grid@summary_table

# select the model with the lowest logloss as the best model
best_model <- h2o.getModel(grid@model_ids[[1]])
best_model

# compute the confusion matrix given the test set extraxted from the imported Training set and view the model accuracy
c_matrix <- h2o.confusionMatrix(best_model, test_h2o)
overall_model_accuracy <- paste0(round(((c_matrix[1,1] + c_matrix[2,2])/(c_matrix[1,1] + c_matrix[1,2] +c_matrix[2,1] + c_matrix[2,2]) * 100),2),"%")
overall_model_accuracy

# model performance
h2o.performance(best_model, test_h2o)

#results <- h2o.predict(best_model, test_h2o)

#convert to R data frame
data1 <- as.data.frame(results)


# Import the actual test dataset and make predictions
test_raw_data <- read.csv(file.choose(), header = T)

# save the Id field in an object as this will be required when writing the submission file
test_dataset_id <- test_raw_data[,1]

# remove the id field from the dataset that will passed for prediction
test_raw_data <- test_raw_data[,-1]

# convert dataset to h2o format so as to be fit to pass into the developed h2o model
actual_testset <- as.h2o(test_raw_data)

# make predictions
results2 <- h2o.predict(best_model, actual_testset)

# convert actual test dataset predicted results to R dataframe
results_data_frame <- as.data.frame(results2)

# merge the Id fields and the predcited results dataframe
Final <- cbind(ID = test_dataset_id, results_data_frame)

# Convert the predicted categorical values back to the original values of 0 and 1 as required to be
# written to submission file
Final$TARGET <- ifelse(Final$predict == "Satisfied" & Final$Satisfied > 0.5, 0, 1)

# write results to Excel(csv) file
write.csv(Final[,c(1,5)], file = "submission.csv", quote=FALSE, row.names=FALSE)

## The End.






