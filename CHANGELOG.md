Version 0.6.4

* Fix Contact header transport bug

Version 0.6.3

* Allow the Contact header to be extended with extra header parameters
* Add the no_new_calls? method to verify that nothing is happening on an endpoint

Version 0.6.2

* Detect and discard retransmissions
* Fix tight loop created by terminating a TCP Endpoint

Version 0.6.1

* Fix bug in status code handling for recv_any_of

Version 0.6.0

* Add recv_any_of method to allow handling messages that may come in an arbitrary order

Version 0.5.1

* Fix bug when deriving Req-URI from a Contact header with multiple pairs of angle brackets

Version 0.5.0

* Add support for setting RFC 5626 instance IDs
* Improve logging by keeping a msg_log variable for each endpoint which stores its sent/received messages

Version 0.4.2

* Fix REGISTER bug - reset branch ID before sending a re-register

Version 0.4.1

* Fix REGISTER bug - make all REGISTERs from an endpoint share a Call-ID as required by the SIP RFC
* Send a dummy Authorization header on initial REGISTERs, to allow the registrar to learn the private ID

Version 0.4.0

*  Beginnings of IMS AKA authentication support
* Rework API - add "dialog_creating" parameter when receiving a message rather than needing a separate API call to indicate this
* Add "assoc_with_msg" method to make it easier to handle multiple transactions at once
* Rename "new_transaction" to "get_new_via_hdr" for clarity

Version 0.3.3

* Fix bug in TCP DNS resolution introduced by 0.3.2

Version 0.3.2

* Started changelog
* Resolve DNS when a connection starts, so that all UDP messages go to the same host
* Strip angle brackets from SIP URI when copying it into the Request-URI

