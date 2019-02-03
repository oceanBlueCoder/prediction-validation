## Assumption

It's assumed that Perl is installed at /usr/bin/perl.

It's assumed that the sliding window is	small than the total expand of the input data set, in other words, the input file should contains enough hours to cover one sliding window.  For example, the following example is considered invalid input, and the code will exit and print a message.

sliding window: 4
all hours found in the input data set: 1, 2, 3


## My Approach

1) Read both actual.txt and predicted.txt, and store the info in a nested hash.  The key of the hash is the hour.  The value of each hour is a hash using the stock symbol as the key.  For each stock symbol, the actual price and the predicted price is stored.

2) Calculate the following 2 items for each hour, and store them in a hash:
a. the total error
b. the number of valid entries.  Those entries with both actual and predicted prices are considered valid.


3) For the first sliding window, sum up the errors in all hours, divided by the number of valid entries.

4) For all following sliding windows, calculate the total errors by adding the error for the next hour, and substracting the error for the first hour.  As an example, if the sliding window is 3, then calculate the first sliding window from 1 ~ 3 in the regular way.  When calculating 2 ~ 4, insteading of adding all errors from scratch, we take the total errors from the previous calculation of 1 ~ 3, substract the error for 1, and add the error for 4.
