PATH_OVERRIDE=/usr/xpg4/bin:$(PWD)/node_modules/http-server/bin:/opt/local/bin:$(PATH)
WELL_KNOWN=/opt/www/dehydrated/.well-known/acme-challenge
FLAGS=

.PHONY: all register cert dep clean test

all: cert

dep: .dehydrated node_modules $(WELL_KNOWN)

$(WELL_KNOWN):
	mkdir -p /opt/ssl $@
	mkdir -p $(WELL_KNOWN)

node_modules:
	npm install --progress=false http-server

.dehydrated:
	git clone https://github.com/dehydrated-io/dehydrated .dehydrated

register: /opt/ssl/accounts

/opt/ssl/accounts: .dehydrated
	./.dehydrated/dehydrated --register --accept-terms

cert: dep register config.local config hook.sh domains.txt $(WELL_KNOWN)
	@PATH="$(PATH_OVERRIDE)" ./.dehydrated/dehydrated -c $(FLAGS)

test: dep config.test config hook.sh domains.txt
	@shellcheck -x hook.sh
	@mkdir -p webroot/dehydrated/.well-known/acme-challenge
	@PATH="$(PATH_OVERRIDE)" ./.dehydrated/dehydrated --register --accept-terms --config config.test -6 $(FLAGS)
	@PATH="$(PATH_OVERRIDE)" ./.dehydrated/dehydrated -c --config config.test -6 $(FLAGS)
	openssl x509 -text -noout -in certs/$$(cat domains.txt)/cert.pem

distclean: depclean clean

depclean:
	rm -rf .dehydrated node_modules

clean:
	rm -rf accounts certs webroot lock
