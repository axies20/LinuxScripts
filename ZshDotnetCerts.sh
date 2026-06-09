#!/usr/bin/env bash
set -e

echo "Configuring .NET for zsh..."

# .NET env
grep -qxF 'export DOTNET_ROOT=$HOME/.dotnet' ~/.zshrc || \
  echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.zshrc

grep -qxF 'export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools' ~/.zshrc || \
  echo 'export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools' >> ~/.zshrc

# OpenSSL / Fedora cert paths
grep -qxF 'export SSL_CERT_DIR=$HOME/.aspnet/dev-certs/trust:/etc/pki/tls/certs:/etc/ssl/certs' ~/.zshrc || \
  echo 'export SSL_CERT_DIR=$HOME/.aspnet/dev-certs/trust:/etc/pki/tls/certs:/etc/ssl/certs' >> ~/.zshrc

# Apply for current script session
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$PATH:$HOME/.dotnet:$HOME/.dotnet/tools"
export SSL_CERT_DIR="$HOME/.aspnet/dev-certs/trust:/etc/pki/tls/certs:/etc/ssl/certs"

echo "Installing system certificate tools..."
sudo dnf install -y ca-certificates p11-kit p11-kit-trust nss-tools openssl
sudo update-ca-trust

sudo mkdir -p /etc/ssl/certs
sudo ln -sf /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt

echo "Creating/trusting ASP.NET HTTPS dev certificate..."
dotnet dev-certs https --clean
dotnet dev-certs https --trust

echo "Checking certificate trust..."
dotnet dev-certs https --check --trust || true

echo "Done. Restart terminal and Rider."