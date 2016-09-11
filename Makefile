PATH_OVERRIDE=/usr/xpg4/bin:./node_modules/http-server/bin:/opt/local/bin:$(PATH)
FLAGS=

.PHONY: all cert dep clean test

all: cert

dep: .letsencrypt.sh node_modules
	mkdir -p /opt/ssl /opt/www/letsencrypt/.well-known/acme-challenge

node_modules:
	npm install http-server

.letsencrypt.sh:
	git clone https://github.com/bahamat/letsencrypt.sh .letsencrypt.sh

cert: dep config.local config hook.sh domains.txt
	@PATH=$(PATH_OVERRIDE) ./.letsencrypt.sh/letsencrypt.sh -c $(FLAGS)

test:
	true

distclean: clean
	rm -rf .letsencrypt.sh node_modules

clean:
	rm -rf accounts certs private_key.json private_key.pem
