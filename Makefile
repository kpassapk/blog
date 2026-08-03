EMACSCLIENT ?= emacsclient
EMACS       ?= emacs
HUGO        ?= hugo
ROOT        := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

.PHONY: help export export-batch build serve clean

help:
	@echo "make export        org/ sources -> content/posts (needs a running Emacs)"
	@echo "make export-batch  same, via a batch Emacs (no server needed)"
	@echo "make build         export, then build static output into public/"
	@echo "make serve         export, then preview on http://localhost:1313"
	@echo "make clean         remove Hugo build output"

# Uses the running Emacs server rather than a batch Emacs, so ox-hugo and
# the rest of the config are already loaded.
export:
	$(EMACSCLIENT) --eval '(progn (load "$(ROOT)/export.el" nil t) (blog-export-all))'

# Fallback when no Emacs server is running.  export.el pulls ox-hugo in from
# the installed packages via package-initialize.
export-batch:
	$(EMACS) --batch --load "$(ROOT)/export.el" --funcall blog-export-all

build: export
	$(HUGO) --minify --source $(ROOT)

serve: export
	$(HUGO) server --source $(ROOT)

clean:
	rm -rf $(ROOT)/public $(ROOT)/resources $(ROOT)/static/ox-hugo
