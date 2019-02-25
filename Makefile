# E.g.  make watch what=target
watch:
	while true; do \
	  make $(what); \
	  inotifywait -qre close_write . ; \
	done

.PHONY: \
  clean \
  build-images \
  sbt \
  up \
  down \
  dead \
  selenium-server \
  invisible-selenium-server \
  git-subm-init-upd \
  minified-asset-bundles \
  play-cli \
  prod-images

.DEFAULT_GOAL := print_help

print_help:
	@echo
	@echo "This is Talkyard's Makefile. Usage:"
	@echo
	@echo "Building production images"
	@echo "--------------------------"
	@echo
	@echo "Edit version.txt and commit. Edit DOCKER_REPOSITORY in .env."
	@echo "Then:"
	@echo
	@echo "  Build production images:  make prod-images"
	@echo "  Push to your repo:        make tag-and-push-latest-images"
	@echo
	@echo "Running a development server"
	@echo "--------------------------"
	@echo
	@echo "  Start a dev server:       make up"
	@echo "  Stop the dev server:      make dead"
	@echo
	@echo "  Open PostgreSQL prompt:   make db-cli"
	@echo "  Start a Scala CLI:        make play-cli  # first do: make dead"
	@echo
	@echo "Running tests"
	@echo "--------------------------"
	@echo
	@echo "End-to-End tests:"
	@echo "  First, start Selenium:    make invisible-selenium-server"
	@echo "  Then run the tests:       make e2e-tests"
	@echo "  Stop Selenium:            make selenium-dead"
	@echo
	@echo "Unit tests:"
	@echo "  Start a Scala CLI:        make play-cli  # first do: make dead"
	@echo "  Run tests:                test  # in the CLI"
	@echo
	@echo "What more do you want to know? Talk with us at"
	@echo "https://www.talkyard.io/forum/."
	@echo


DOCKER_REPOSITORY := \
  $(shell sed -nr 's/DOCKER_REPOSITORY=([a-zA-Z0-9\._-]*).*/\1/p' .env)

TALKYARD_VERSION := \
  $(shell cat version.txt)

define ask_for_root_password
  sudo echo
endef



# ----- Git submodules

# This'll be all Git submodule directories. If some are missing, need to git-clone them.
git_modules := \
  $(shell grep submodule .gitmodules | sed -r 's/^.submodule "([^"]+).*$$/\1\/.git/')

git-subm-init-upd: $(git_modules)

$(git_modules): $@
	git submodule update --init



# ----- Javascript and CSS bundles


# If these are present, probably all js modules have been installed?
node_modules: \
            node_modules/.bin/gulp
            #node_modules/react/umd/react.development.js \
            #node_modules/zxcvbn/dist/zxcvbn.js

node_modules/.bin/gulp: git-subm-init-upd
	s/yarn

# BUG RISK sync with Gulp so won't accidentally forget to (re)build? [GZPATHS]
# Sync with the languages in the /translations/ dir. [5JUKQR2]
#  public/res/2d-bundle.min.js.gz // [SLIMTYPE]
zipped_bundles:=\
  images/web/assets/talkyard-comments.min.js.gz \
  images/web/assets/talkyard-service-worker.min.js.gz \
  images/web/assets/$(TALKYARD_VERSION)/editor-bundle.min.js.gz \
  images/web/assets/$(TALKYARD_VERSION)/jquery-bundle.min.js.gz \
  images/web/assets/$(TALKYARD_VERSION)/more-bundle.min.js.gz \
  images/web/assets/$(TALKYARD_VERSION)/slim-bundle.min.js.gz \
  images/web/assets/$(TALKYARD_VERSION)/staff-bundle.min.js.gz \
  images/web/assets/$(TALKYARD_VERSION)/styles-bundle.min.css.gz \
  images/web/assets/$(TALKYARD_VERSION)/zxcvbn.min.js.gz \
  images/web/assets/$(TALKYARD_VERSION)/translations/en_US/i18n.min.js.gz \
  images/web/assets/$(TALKYARD_VERSION)/translations/pl_PL/i18n.min.js.gz \
  images/app/assets/server-bundle.min.js.gz \
  images/app/assets/translations/en_US/i18n.min.js.gz \
  images/app/assets/translations/pl_PL/i18n.min.js.gz

minified-asset-bundles: node_modules $(zipped_bundles)

$(zipped_bundles): $@
	sudo s/d-gulp release



# ----- Clean (wip)

clean-bundles:
	@echo Delting script and style bundles:
	rm -f  public/res/*.js
	rm -f  public/res/*.js.gz
	rm -f  public/res/*.css
	rm -fr public/res/translations/

clean: clean-bundles
	@echo Delting Scala things and other things:
	rm -fr target/
	rm -fr project/target/
	rm -fr project/project/
	rm -f  tests/e2e-failures.txt
	rm -f  ensime-langserver.log
	rm -f  chromedriver.log

pristine: clean
	@echo
	@echo "If you want to, delete Docker volumes, your local config,"
	@echo "the SBT and Node.js cache, and IDE project files,"
	@echo "by copy-pasting (some of) this:"
	@echo
	@echo "    sudo rm -rf volumes/"
	@echo "    rm -fr conf/my.conf"
	@echo
	@echo "    rm -fr .idea"
	@echo "    rm -fr .ensime"
	@echo "    rm -fr .ensime_cache/"
	@echo
	@echo "    rm -fr node_modules/"
	@echo "    rm -fr modules/*/node_modules/"
	@echo
	@echo "    rm -fr ~/.ivy2"
	@echo "    rm -fr ~/.sbt"
	@echo
	@echo


# ----- Run targets

# Starts an SBT shell where you can run unit tests by typing 'test'. These test require
# the minified asset bundles, to run (because the app server loads and execs React Javascript
# server side.)
play-cli: minified-asset-bundles
	sudo s/d-cli

db-cli:
	@# Find out which database is currently being used, by looking at my.conf.
	@# Because I sometimes connect as the wrong user, and feel confused for quite a while.
	@def_user=`sed -nr 's/^talkyard.postgresql.user="([a-zA-Z0-9\._-]+)".*/\1/p' conf/my.conf`  ;\
	  def_user="$${def_user:-talkyard}" ;\
	  read -p "Connect to the PostgreSQL database as which user? [$$def_user] " db_user ;\
	  db_user="$${db_user:-$$def_user}" ;\
	  sudo s/d-psql "$$db_user" "$$db_user"

up: minified-asset-bundles
	sudo s/d up -d
	@echo
	@echo "Started. Now, tailing logs..."
	@echo
	@sudo s/d-logsf0

tails: tail
tail:
	sudo s/d-logsf0

restart:
	sudo s/d-restart

restart-web:
	sudo s/d kill web ; sudo s/d start web ; sudo s/d-logsf0

restart-app:
	sudo s/d kill app ; sudo s/d start app ; sudo s/d-logsf0

restart-web-app:
	sudo s/d-restart-web-app

restart-gulp:
	sudo s/d kill gulp ; sudo s/d start gulp ; sudo s/d-logsf0

down:
	sudo s/d down

dead:
	sudo s/d-killdown

dead-app:
	sudo s/d kill web app



# E2E tests
# ========================================


# ----- Starting Selenium

_selenium_standalone_files := \
  node_modules/selenium-standalone/bin/selenium-standalone  \
  node_modules/selenium-standalone/.selenium/chromedriver/ \
  node_modules/selenium-standalone/.selenium/geckodriver/

$(_selenium_standalone_files): $@
	s/selenium-install

selenium-dead:
	kill $$(ps aux | grep selenium | grep -v 'xvfb-run' | awk '{ print $$2 }')

selenium-server: node_modules $(_selenium_standalone_files)
	@$(call if_selenium_not_running, s/selenium-start)


invisible-selenium-server: node_modules $(_selenium_standalone_files)
	@$(call if_selenium_not_running, s/selenium-start-invisible)

define if_selenium_not_running
  selenium_line=`netstat -tlpn 2>&1 | grep '4444'` ;\
  if [ -z "$$selenium_line" ]; then \
    echo "Starting Selenium." ;\
    $(1) & echo $$! > .selenium.pid ;\
  else \
    echo ;\
    echo "Selenium already running. Not starting it." ;\
    echo ;\
    echo "Look, from netstat, port 4444 is in use:" ;\
    echo "  $$selenium_line" ;\
    echo ;\
  fi
endef

e2e-tests: invisible-selenium-server
	s/run-e2e-tests.sh
	if [ -f .selenium.pid ]; then kill `cat .selenium.pid`; rm .selenium.pid ; fi

visible-e2e-tests: selenium-server
	s/run-e2e-tests.sh
	if [ -f .selenium.pid ]; then kill `cat .selenium.pid`; rm .selenium.pid ; fi

# Alternative to above if-then-fi for the PID file;
# start: server.PID
# server.PID:
#     cd bin && { s/selenium-start-invisible & echo $$! > $@; }
# stop: server.PID
#     kill `cat $<` && rm $<
# see: https://stackoverflow.com/a/23366404/694469


# Images (wip)
# ========================================


dev-images: minified-asset-bundles
	sudo docker-compose build


prod-images: \
			invisible-selenium-server
	@# This builds minified-asset-bundles.
	s/build-prod-images.sh


tag-and-push-latest-images:  tag-latest-images  push-tagged-images  _print_push_git_tag_command


tag-latest-images:
	@$(call die_unless_tag_specified, Tag with)
	@$(call ask_for_root_password)
	REPO=$(DOCKER_REPOSITORY)  ;\
	sudo docker tag $$REPO/talkyard-app $$REPO/talkyard-app:$(tag)  ;\
	sudo docker tag $$REPO/talkyard-web $$REPO/talkyard-web:$(tag)  ;\
	sudo docker tag $$REPO/talkyard-rdb $$REPO/talkyard-rdb:$(tag)  ;\
	sudo docker tag $$REPO/talkyard-cache $$REPO/talkyard-cache:$(tag)  ;\
	sudo docker tag $$REPO/talkyard-search $$REPO/talkyard-search:$(tag)  ;\
	sudo docker tag $$REPO/talkyard-certgen $$REPO/talkyard-certgen:$(tag)
	@echo


push-tagged-images:
	@$(call die_unless_tag_specified, Push)
	@$(call ask_for_root_password)
	REPO=$(DOCKER_REPOSITORY)  ;\
	sudo docker push $$REPO/talkyard-app:$(tag)  ;\
	sudo docker push $$REPO/talkyard-web:$(tag)  ;\
	sudo docker push $$REPO/talkyard-rdb:$(tag)  ;\
	sudo docker push $$REPO/talkyard-cache:$(tag)  ;\
	sudo docker push $$REPO/talkyard-search:$(tag)  ;\
	sudo docker push $$REPO/talkyard-certgen:$(tag)
	@echo


_print_push_git_tag_command:
	@echo "Next:"
	@echo ""
	@echo "    make push-tag-to-git tag=$(tag)"
	@echo ""


push-tag-to-git:
	@$(call die_unless_tag_specified, Push) ;\
	
	@echo
	@echo "Publishing version tag $(tag) to GitHub..."
	 
	@cd modules/ed-versions/  ;\
	git fetch  ;\
	git checkout master  ;\
	git merge --ff-only origin master  ;\
	echo $(tag) >> version-tags.log  ;\
	git add version-tags.log  ;\
	git commit -m "Add $(tag)."  ;\
	git push origin master
	
	@echo ""
	@echo "Tagging the current Git revision with $(tag) ..."
	
	@git tag $(tag)
	@git push origin $(tag)
	
	@echo ""
	@echo "Done. Now, bump the version number:"
	@echo ""
	@echo "    s/bump-versions.sh"
	@echo ""


define die_unless_tag_specified
  if [ -z "$(tag)" ]; then \
    echo ;\
    echo "Error: $(1) which Docker image tag? Specify   tag=...  please."  ;\
    echo ;\
    exit 1  ;\
  fi
endef



# ----- Maybe read (again)?

#https://gist.github.com/mpneuried/0594963ad38e68917ef189b4e6a269db
# DOCKER_REPO=...

# http://datakurre.pandala.org/2016/04/evolution-of-our-makefile-for-docker.html
# capture test exit status code: ... see blog post


# https://serversforhackers.com/c/dckr-dev-workflow  — log messages


# maybe read:
# http://aegis.sourceforge.net/auug97.pdf

# has read:
# https://serversforhackers.com/c/dckr-dev-workflow


# probably well constructed:
#  https://github.com/PistonDevelopers/rust-empty/blob/master/Makefile
#  https://github.com/git/git/blob/master/Makefile

# Bazel? No? Then everyone incl I need to spend time learning how it works:
#  https://github.com/bazelbuild/rules_k8s  and need to install Java.


# looks nice:
#   https://github.com/casey/just



# vim: list ts=4 sw=4 tw=0 fo=r
