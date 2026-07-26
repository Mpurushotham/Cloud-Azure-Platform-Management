# Minimal image whose only job is to prove the ACR -> AKS pull path works
# using the kubelet's managed identity (AcrPull) — no imagePullSecret anywhere.
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
