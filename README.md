# make-cert

`make-cert` is an opinionated certficate deployment system  wrapping
[dehydrated][dehydrated].  While `dehydrated` is a high quality
[Let's Encrypt][letsencrypt] client, making sure `config` and `hook.sh` are
deployed correctly each time became a hassle for me. I made this so that most
choices are already made and each deployment can have the barest minimum
individual configuration.

[dehydrated]: https://github.com/bahamat/dehydrated
[letsencrypt]: https://www.letsencrypt.org/

## Usage

1. Clone the repo
2. Edit `config.local` to set your email address and change to the production
   API URL when ready.
3. Add domains to `domains.txt`. See the [`dehydrated`
   documentation][domains_doc] for details.
4. Run `make cert`

[domains_doc]: ../../../dehydrated/blob/master/docs/domains_txt.md

E.g.

    $ cat config.local
    CA="$prod_ca"
    CONTACT_EMAIL=nobody@nowhere.edu
    $ cat domains.txt
    www.example.com example.com
    $ make cert
    ...

### Renewing Certificates

It's best to create a cron job for certificate renewal. Because (nearly)
everything is packaged into the `Makefile` this is much simplified.

This example job will run at 12:15 AM on Tuesdays.

    15 0 * * 2 make -C /path/to/make-cert >> /var/log/make-cert.log 2>&1

## Enhancements

My `config` file sources `trace_logger.sh` and `error_handler.sh` by
[Joyent][sdc-headnode]. The error handler provides stack traces to identify
where/why cert generation failed. This is always enabled. The trace logger
enables `bash`'s `xtrace` for additional observability. This is optional and
can be enabled by setting the `TRACE` environment variable to any value other
than `off`.

Example usage:

    make cert TRACE=on

[sdc-headnode]: https://github.com/joyent/sdc-headnode/tree/master/buildtools/lib

## Assumptions

Being opinionated certificate deployment, there are a number of assumptions
made.

1. Node.js and npm are installed and in the default `$PATH`.
2. Certificate challenges will be handled by HTTP, not DNS.
3. A web root of`/opt/www/dehydrated` is used for the location of
   `.well-known`. This will be created if it does not exist. There are example
   web server virtualhost configuration files for Apache and Nginx that are
   preconfigured for this location.
4. If there is nothing listening on port 80, a node.js http-server will be
   spawned to process acme challenge requests.
5. Certifcates are output to `/opt/ssl/certs`. Your application(s) should refer
   to those files for the SSL certificates.
6. ECDSA keys will be generated using the prime256v1 curve.

If you don't like any of these assumptions, override them in `config.local` or
fork and do as you please. The point of `make-cert` is *not* to be flexible!
It is to have a strictly formatted framework that applications can depend on.

If you think additional assumptions might be helpful, open a pull request!

## Supported Platforms

illumos and FreeBSD are directly supported. Adding support for additional
platforms is a matter of properly detecting something listening on port 80 in
`hook.sh`.

Application restart support is limited to Apache and Nginx on SmartOS (see
issues).

## License

The following files are licensed under the MPL-2.0 license. See `LICENSE.mpl-2`
for details.

* `error_handler.sh`
* `trace_logger.sh`

All other files are licensed under the MIT license. See `LICENSE` for details.
