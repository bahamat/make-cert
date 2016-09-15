PATH_OVERRIDE=/usr/xpg4/bin:./node_modules/http-server/bin:/opt/local/bin:$(PATH)
FLAGS=

.PHONY: all cert dep clean test

all: cert

dep: .dehydrated node_modules
	mkdir -p /opt/ssl /opt/www/letsencrypt/.well-known/acme-challenge

node_modules:
	npm install --progress=false http-server

.dehydrated:
	git clone https://github.com/bahamat/dehydrated .dehydrated

cert: dep config.local config hook.sh domains.txt
	@PATH=$(PATH_OVERRIDE) ./.dehydrated/dehydrated -c $(FLAGS)

test:
	true

distclean: clean
	rm -rf .dehydrated node_modules

clean:
	rm -rf accounts certs private_key.json private_key.pem
