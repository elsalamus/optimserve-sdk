# Apple dependency provenance

OptimServe's wrapper source is MIT-licensed. This does not license its dependencies.

The upstream Git repository wrapper has an MIT LICENSE, but the 3.6.1
SwarmCloudKit.podspec explicitly labels the framework Commercial. The full framework
archive's LICENSE.md links to https://www.swarmcloud.net/guides/contract.
Do not infer redistribution permission from the repository's wrapper license.
No upstream Apple binaries are included in this source package or public allowlist.

Source: https://github.com/swarm-cloud/SwarmCloudKit
Framework version: 3.6.1; SHA-256 of its upstream XCFramework archive:
0acb5fdb8695aae5e9bbb8a5052771c0345d6fe2ee2e873788e8c5f030afc5cd
Datachannel wrapper: 1.0.232; SHA-256:
6244e4da6c6901639e58014771ec4a86cf46f1c371a9ad6802bc190e54b4e466

Compilation checks download pinned dependencies into a temporary directory, publish
no dependency/build artifacts and do not use the SwarmCloud service.
