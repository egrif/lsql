#!/bin/bash

# Setup script to install lsql gem locally and configure for easy updates

set -e

echo "Setting up LSQL gem for local development..."

# Build the gem
echo "Building gem..."
gem build lsql.gemspec

# Install the gem
echo "Installing gem..."
GEM_FILE=$(ls lsql-*.gem | head -1)
gem install "$GEM_FILE"

echo "✅ LSQL gem installed successfully!"
echo "You can now run 'lsql --help' from any directory"
echo ""
echo "To update to the latest version, run this script again:"
echo "  ./setup_local_gem.sh"
echo ""
echo "Or manually:"
echo "  gem build lsql.gemspec && gem install ./lsql-*.gem"
