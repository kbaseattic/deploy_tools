all:


test:
	for t in $(shell ls ./t/*.t); do \
		echo $$t; \
		perl $$t; \
	done 
