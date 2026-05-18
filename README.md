# Troodi VPN

**Enterprise secure access client for policy-based network connectivity.**

Troodi VPN is a desktop VPN and secure routing client built around
**Xray-core**. It is designed for professional and corporate environments where
users need encrypted connectivity, predictable routing policies, and simple
operational controls without manually editing low-level network configuration.

The project focuses on making advanced network routing understandable for end
users while keeping the underlying system flexible enough for security-focused
deployments.

<img width="1429" height="1001" alt="Troodi VPN desktop dashboard" src="https://github.com/user-attachments/assets/c54e93b9-9880-41cb-8db7-9e303c80e88a" />

---

## Overview

Modern teams need secure access across remote workstations, office networks,
cloud environments, and private infrastructure. Troodi VPN provides a controlled
desktop client for encrypted connectivity, traffic segmentation, and
policy-based routing.

The application is built to support:

- secure remote access to corporate resources
- full-tunnel and selective routing workflows
- per-domain, per-IP, and subnet-level traffic policies
- multiple connection profiles for different environments
- clear connection status, latency, and traffic visibility

---

## Security-Focused Capabilities

- **Encrypted transport** powered by Xray-core protocols such as VLESS and
  Reality
- **TUN mode** for full-device encrypted network routing
- **Proxy mode** for application-level connectivity scenarios
- **Policy-based routing** for domain, IP, and subnet rules
- **Traffic control actions** for secure tunnel, direct local route, or deny
- **Profile isolation** for separating corporate, development, staging, and
  production access
- **Live network telemetry** including ping, external IP, and traffic counters
- **Cross-platform desktop UI** built with Flutter for predictable user
  experience

---

## Protocol Choice

Troodi VPN uses Xray-core with VLESS and Reality because these transports are
well suited for controlled corporate environments where encrypted connections
must remain stable under strict outbound network policies.

In many enterprise and financial systems, workstations operate behind
allowlists, segmented networks, endpoint protection, and tightly managed
egress rules. The protocol layer is selected to support:

- persistent encrypted sessions across managed network paths
- reliable connectivity for remote employees and contractors
- low operational overhead compared with manually maintained VPN
  configurations
- clear separation between transport security, routing policy, and user-facing
  profile management
- compatibility with full-tunnel and selective-routing deployments

The goal is to operate within governance controls while providing a predictable
secure transport layer that can be deployed and audited as part of a broader
corporate access model.

---

## Corporate Network Use Cases

Troodi VPN is positioned as a secure access layer for organizations and
technical teams that need controlled connectivity without exposing users to
complex VPN configuration.

Typical use cases include:

- secure access to internal dashboards, private APIs, and cloud management
  panels
- split-tunnel deployments for balancing security, performance, and local
  network availability
- least-privilege network access for contractors, engineers, and remote
  employees
- separated connection profiles for development, staging, production, and
  administrative environments
- workstation-level policy enforcement for managed desktop deployments

---

## Policy-Based Routing

Troodi VPN includes a routing engine that applies deterministic traffic
policies before network requests leave the workstation.

Supported rule targets:

- domains, such as `internal.example.com`
- IP addresses, such as `10.10.20.15`
- subnets, such as `10.0.0.0/8`

Supported policy outcomes:

- **Secure Tunnel**: route traffic through the encrypted VPN connection
- **Direct**: keep trusted local or corporate network resources on their
  intended route
- **Deny**: block traffic at the client policy layer

This gives administrators and technical users a practical way to segment
traffic, reduce accidental exposure, and keep sensitive resources behind
encrypted access paths.

<img width="3068" height="2160" alt="Troodi VPN routing rules screen" src="https://github.com/user-attachments/assets/8a7c578d-c439-4d7c-8471-778540140dc7" />

---

## Profiles

Troodi VPN supports multiple connection profiles so users can switch between
network environments without rebuilding configuration manually.

Profiles can represent:

- corporate VPN gateways
- development or staging infrastructure
- production administration paths
- regional or environment-specific routing policies
- temporary access configurations for project-based work

Each profile keeps its own connection settings and routing behavior, making it
easier to operate securely across different infrastructure contexts.

---

## Architecture

Troodi VPN combines a desktop interface, a local backend manager, and a proven
networking runtime.

- **Flutter UI**: cross-platform desktop application layer
- **Go backend**: local process manager, API layer, and configuration bridge
- **Xray-core runtime**: encrypted transport and routing engine
- **Structured configuration**: profile-based settings and routing policies
- **Platform integration**: support for desktop networking features such as TUN
  mode

This architecture demonstrates systems integration across desktop UX, network
process orchestration, policy configuration, and secure transport runtime
management.

---

## Engineering Scope

The project demonstrates practical work in several security and infrastructure
engineering areas:

- endpoint networking and VPN client architecture
- secure traffic routing and network segmentation
- Go-based runtime orchestration for external networking engines
- cross-platform desktop development with Flutter
- profile-driven configuration design
- user-facing abstractions for complex network security behavior

---

## Tech Stack

- **Xray-core**: encrypted networking and routing runtime
- **Go**: backend service and runtime orchestration
- **Flutter**: cross-platform desktop UI
- **JSON configuration**: profiles, routing rules, and runtime settings

---

## Supported Platforms

- Windows x64
- Linux, including Debian and Ubuntu

---

## Operational Notes

- Administrator privileges may be required for TUN mode.
- Network behavior depends on the active profile, routing policy, and server
  deployment.
- Endpoint protection tools may inspect or flag VPN runtime binaries; enterprise
  deployments should use vetted, signed, and allowlisted builds.
- Security and compliance depend on server hardening, key lifecycle management,
  access control, logging policy, and deployment procedures.

---

## Roadmap

- Admin-managed profile distribution
- Organization-level routing policy templates
- Signed release pipeline and update verification
- Privacy-preserving audit and diagnostics tools
- Additional managed-device deployment options

---

## Keywords

enterprise VPN, secure remote access, policy-based routing, zero-trust access,
network segmentation, endpoint security, encrypted transport, Xray-core, VLESS,
Reality, TUN mode, Flutter desktop, Go networking

---

## License

MIT
