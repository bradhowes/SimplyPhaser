#!/bin/bash

# Package.swift
# .package(url: "https://github.com/bradhowes/AUv3Support", branch: "main")
# .package(path: "../AUv3Support")

cp Packages/Package.swift Packages/Package.swift.old
sed -e 's/url: "https://github.com/bradhowes/AUv3Support", branch: "main"/path: "../AUv3Support"/' Packages/Package.swift

# isa = XCRemoteSwiftPackageReference;
# repositoryURL = "https://github.com/bradhowes/AUv3Support";
# requirement = {
#   branch = main;
#   kind = branch;
# };
