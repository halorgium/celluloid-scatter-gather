celluloid-scatter-gather
========================

This is an attempt to show how to do scatter/gather on top of Celluloid. 

The demo uses 10 workers which have a random timeout for producing their result. 
A success is considered at least 3 results within 6 seconds. 

There are two log outputs: 
* [success](https://github.com/halorgium/celluloid-scatter-gather/blob/master/success.log): enough results were generated within the timeout period
* [error](https://github.com/halorgium/celluloid-scatter-gather/blob/master/error.log): not enough results were generated within the timeout period

You can run this yourself. The nicer logging is not yet on master, sorry. 

``` sh
bundle
bundle exec ruby demo.rb
