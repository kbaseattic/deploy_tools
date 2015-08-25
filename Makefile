all:

docker:
	docker build -t kbase/deplbase:latest .

test:
	for t in $(shell ls ./t/*.t|grep -v provision); do \
		echo $$t; \
		perl $$t; \
	done 

test-provision:
	perl ./t/provision.t
