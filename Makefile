# GreenChain — build the Flutter web app and deploy it to the GitHub Pages folder.
#
# The deploy folder is a separate git repo published via GitHub Pages.
#
# BASE_HREF must match how the site is served. The site is served at the
# custom domain https://app.frutasdeliciosas.store/ (CNAME lives in web/,
# so it is included in every build) -> base href is /
# Override on the command line if needed, e.g.:
#   make deploy BASE_HREF=/veg_shop_manager/      (project page, no custom domain)
#   make deploy DEPLOY_DIR="/path/to/other/folder"

DEPLOY_DIR ?= /Users/muhammadmohsin/Documents/Learning/Nabeel Spain/veg_shop_manager_build
BASE_HREF  ?= /

.PHONY: build deploy deploy-push clean run test

## Build the release web bundle
build:
	flutter build web --release --base-href "$(BASE_HREF)"

## Build and copy the bundle into the GitHub Pages folder
deploy: build
	@mkdir -p "$(DEPLOY_DIR)"
	rsync -a --delete --exclude '.git' build/web/ "$(DEPLOY_DIR)/"
	# GitHub Pages: don't run Jekyll, and serve the SPA on deep-link refreshes
	@touch "$(DEPLOY_DIR)/.nojekyll"
	@cp "$(DEPLOY_DIR)/index.html" "$(DEPLOY_DIR)/404.html"
	@echo ""
	@echo "Deployed to $(DEPLOY_DIR)"
	@echo "Commit & push with:  make deploy-push   (or do it manually in that folder)"

## Build, copy, then commit & push the GitHub Pages folder (one command)
deploy-push: deploy
	cd "$(DEPLOY_DIR)" && git add -A && \
		(git diff --cached --quiet || git commit -m "deploy $$(date +%Y-%m-%dT%H:%M)") && \
		git push -u origin HEAD

## Run locally in Chrome
run:
	flutter run -d chrome

test:
	flutter test

clean:
	flutter clean
