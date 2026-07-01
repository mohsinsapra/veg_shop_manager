# GreenChain — build the Flutter web app and deploy it to the GitHub Pages folder.
#
# The deploy folder is a separate git repo published via GitHub Pages.
#
# BASE_HREF must match how the site is served:
#   - Project page  https://<user>.github.io/veg_shop_manager_build/  -> /veg_shop_manager_build/
#   - User/root page or custom domain                                 -> /
# Override on the command line if needed, e.g.:
#   make deploy BASE_HREF=/
#   make deploy DEPLOY_DIR="/path/to/other/folder"

DEPLOY_DIR ?= /Users/muhammadmohsin/Documents/Learning/Nabeel Spain/veg_shop_manager_build
BASE_HREF  ?= /veg_shop_manager_build/

.PHONY: build deploy deploy-push clean run test

## Build the release web bundle
build:
	flutter build web --release --base-href "$(BASE_HREF)"

## Build and copy the bundle into the GitHub Pages folder
deploy: build
	@mkdir -p "$(DEPLOY_DIR)"
	rsync -a --delete --exclude '.git' --exclude 'CNAME' build/web/ "$(DEPLOY_DIR)/"
	# GitHub Pages: don't run Jekyll, and serve the SPA on deep-link refreshes
	@touch "$(DEPLOY_DIR)/.nojekyll"
	@cp "$(DEPLOY_DIR)/index.html" "$(DEPLOY_DIR)/404.html"
	@echo ""
	@echo "Deployed to $(DEPLOY_DIR)"
	@echo "Commit & push with:  make deploy-push   (or do it manually in that folder)"

## Build, copy, then commit & push the GitHub Pages folder
deploy-push: deploy
	cd "$(DEPLOY_DIR)" && git add -A && \
		git commit -m "deploy $$(date +%Y-%m-%dT%H:%M)" && \
		git push

## Run locally in Chrome
run:
	flutter run -d chrome

test:
	flutter test

clean:
	flutter clean
