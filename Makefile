test:
	swift test --parallel

docker-build-image:
	docker build -t liquid-local-driver-image .

docker-run: docker-build-image
	docker run \
	--name liquid-local-driver-instance \
	-v $(PWD):/app \
	-w /app \
	-e "PS1=\u@\w: " \
	--rm \
	-it liquid-local-driver-image
