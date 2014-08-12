Quaff is a Ruby library for writing SIP test scenarios. It is an
attempt to create something similar to [SIPp](http://sipp.sf.net) (which I also maintain),
but which can be more easily integrated into other test suites.

The current version is 0.6.2, and it can be installed as a Ruby gem
with 'gem install quaff' (see
[the RubyGems page](https://rubygems.org/gems/quaff) for more info).
Quaff does not support SDP, but
[the separate SDP gem](https://rubygems.org/gems/sdp) can be used to
parse SDP bodies.

A set of example Quaff scripts are available [here](https://github.com/rkday/quaff-examples).

This is still an early stage of Quaff's development, and the API is
likely to change before the 1.0.0 release. (Hopefully, lots of bugs
will be flushed out too - please report any you find on Github.)
