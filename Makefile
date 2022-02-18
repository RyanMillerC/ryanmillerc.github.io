.PHONY: build install serve

build:
	jekyll build

install:
	bundle install

serve:
	jekyll serve --watch --port 8000
