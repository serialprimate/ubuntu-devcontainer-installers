# Installation-script handling investigation

## Purpose and status

This document records post-MVP milestone 2's security boundary for remote installation scripts and its comparison of direct Dockerfile handling with generic and tool-specific installers. The resulting `github-release` installer is available in the source tree and release `0.3.0`; this document does not approve execution of unverified remote code.

The initial conclusion is that moving download-and-execute logic from a Dockerfile into a generic installer does not itself make the operation secure. Security comes from an explicit trust decision over the exact bytes executed, constrained execution inputs and visible ownership of the resulting system changes. A reusable installer can enforce those controls consistently, but a generic interface also broadens authority and can conceal tool-specific behaviour. The project's expert-developer, development-only audience makes an explicit literal argument and non-secret environment interface reasonable; it does not make shell evaluation, accidental secret disclosure or an unauthenticated source safe. The default design direction is therefore direct Dockerfile composition or a tool-specific installer unless multiple demonstrated tools share the same complete integrity and execution contract.

## Predecessor review

The predecessor `install-script` Feature:

- accepted a URL, one dynamically evaluated shell word list for arguments and another for environment assignments;
- followed redirects and retried downloads;
- checked only that the response was non-empty;
- executed the response with Bash as root; and
- removed the temporary file and propagated fetch or script failures.

This provided transport and failure handling, but no content authentication. HTTPS authenticated the contacted endpoint and protected transport; it did not establish that the downloaded bytes were the intended release. A version-looking or commit-looking URL was not independently verified. Following redirects could also change the effective source.

The dynamic word-list handling used `eval`, allowing command substitution and other caller-provided shell syntax to execute as root before the downloaded script. That behaviour is prohibited by the current project contract and will not be reused. Any future arguments must use a repeatable literal `--argument` option. Environment assignment, if justified, must likewise preserve literal values without evaluation.

The predecessor `search-cli-tools` Feature demonstrates one script-only use: it fetched the Brave Search CLI installer from the mutable `main` branch and evaluated the response with `sh -c`. This is evidence of desired functionality, but not evidence that a generic executor is required or that this source-selection mechanism is acceptable.

## Assets and trust boundaries

Assets requiring protection are:

- the integrity and reproducibility of the resulting development image;
- build credentials and other secrets available to the build step;
- the build host and builder cache within the authority granted to the build;
- files, package repositories, users, permissions and commands created in the image; and
- the auditability of which source bytes produced those changes.

The consuming Dockerfile author chooses the source, expected digest, arguments, execution user, prerequisites, layer boundaries and any BuildKit secret mounts. The installer collection is trusted to implement its documented checks correctly. The remote origin and every redirect target are external trust boundaries. A remote script executes with all authority of its process—normally root during this project's image builds—and may invoke the network, modify the whole stage, consume mounted secrets and affect cacheable output.

A checksum authenticates content only relative to the channel or reviewer that supplied the expected checksum. A checksum fetched from the same mutable or compromised location as the script does not create an independent trust boundary. A signature or provenance statement is stronger only when its identity, key or builder policy is independently pinned and actually verified. SLSA similarly requires verification that the provenance subject matches the artifact digest and that the signer and builder satisfy the consumer's trust policy.

## Threats and required controls

| Threat | Required secure-path control | Residual risk |
| --- | --- | --- |
| Mutable URL serves different code | Require an expected SHA-256 digest over the exact response bytes; prefer immutable upstream source selection as an additional review aid | A correctly pinned malicious script still executes with full process authority |
| Origin, CDN or account compromise | Verify against a digest selected through an independent review or trusted release channel | Compromise before digest review can bless malicious bytes |
| Redirect changes source or protocol | Require HTTPS for the initial URL and every redirect, bound redirect count, reject HTTPS downgrade and record the effective URL; optionally restrict redirect hosts for a tool-specific source | An allowed third-party CDN remains another trusted operator |
| Partial, empty or error response is executed | Download with HTTP failure handling to a unique temporary file, require a non-empty regular file, verify before execution and never stream into a shell | A valid but semantically wrong response can match only if the expected digest is also wrong |
| Caller input becomes shell syntax | Preserve each repeatable argument literally in a Bash array and invoke `bash -- "$script" "${arguments[@]}"`; never use `eval`, `sh -c` or reconstructed command strings | The downloaded script can interpret its own arguments as expressions |
| Environment input becomes shell syntax or leaks | Parse each repeatable `--environment NAME=VALUE` literally, validate the name and pass the resulting array through `env`; document that values are non-secret | Values written in a Dockerfile invocation remain visible in source and build metadata; the downloaded script controls its own use of each value |
| Script obtains excessive authority | Make root execution explicit; use a tool-specific non-root mode only when its complete filesystem contract supports it; do not imply that temporary-file execution is sandboxing | Most installation scripts legitimately require broad image-stage authority |
| Secret leaks through CLI, logs, history or image metadata | Do not accept secret values as installer arguments, `--environment` values or URLs; inherit consuming-Dockerfile BuildKit secret mounts only when deliberately exposed to the process | The remote script can read and exfiltrate any secret deliberately exposed to its process |
| Verification failure triggers unsafe fallback | Fail closed; an unverified mode, if approved, must be an explicit controlled-risk operation rather than fallback behaviour | Explicit unverified execution remains arbitrary remote root-code execution |
| Script failure leaves ambiguous state | Execute only after all local validation, propagate the exact non-zero outcome in an actionable diagnostic and clean temporary resources on every exit | Docker discards a failed build result, but remote side effects and mutable caches may remain |
| Repeated invocation conflicts | Document the motivating tool's idempotent, replace, multi-instance or single-instance semantics; expose collision-relevant values and test conflicts | A generic executor cannot infer arbitrary script semantics |

## Direct Dockerfile handling versus reusable installers

### Direct Dockerfile-scripted solution

A direct solution keeps source selection, digest and execution adjacent to the tool being installed. BuildKit can validate a remote `ADD` input with `--checksum`, and a Dockerfile can instead download to a file and verify it before a literal Bash invocation. This improves review locality: the consuming project owns the URL, checksum update and resulting layer.

Its principal security advantage is not Dockerfile syntax itself. It is reduced genericity and explicit policy at the call site. The author can constrain redirects, prerequisites, interpreter, user and expected filesystem result for one tool. Its disadvantages are duplicated verification code, uneven error handling and the likelihood that consumers reproduce unsafe `curl | sh` examples. Remote `ADD --checksum` also validates SHA-256 content but does not by itself define redirect policy, script arguments, execution authority, cleanup or post-install assertions.

### Generic installer

A generic installer can centralise strict URL parsing, download hardening, SHA-256 verification, temporary-resource cleanup, literal argument handling and diagnostics. Those are meaningful benefits when every caller needs the same contract.

The security cost is a reusable arbitrary-code execution primitive. It cannot understand whether a script should run as root, what files it may replace, whether repeated execution is safe, which redirect hosts are legitimate, whether network access after download is expected or whether a supplied environment value is secret. A broad option surface tends to recreate a shell command language, and a stable generic interface can make a dangerous operation appear project-endorsed merely because its mechanics are consistent. A defect in the common downloader also affects every use.

### Semi-generic or tool-specific installer

A narrow installer can reuse small download-and-digest helpers while owning a fixed upstream identity, redirect policy, interpreter, allowed options, prerequisites, installed outputs and repeated-invocation contract. This retains consistent mechanics without presenting arbitrary remote execution as the product interface. It can also avoid the bootstrap script entirely when the upstream release contains directly verifiable binaries or archives.

The cost is one maintained installer per tool and deliberate review whenever upstream distribution changes. For this project, that cost is generally a security benefit: upstream changes cannot silently pass through a generic executor.

## Comparative decision matrix

| Property | Direct Dockerfile | Generic installer | Tool-specific installer |
| --- | --- | --- | --- |
| Trust decision visible beside tool use | Strong | Medium | Strong |
| Consistent verification mechanics | Depends on consumer | Strong | Strong with shared helper |
| Tool-specific redirect and source policy | Strong | Weak unless caller configures it | Strong |
| Tool-specific post-install assertions | Strong | Not generally possible | Strong |
| Literal argument support | Straightforward with careful arrays | Enforceable | Enforceable and narrow |
| Repeated-invocation semantics | Consumer-owned | Fundamentally unknowable | Documentable and testable |
| Risk of becoming an arbitrary root executor | Local to one build | Highest | Bounded to one upstream tool |
| Maintenance duplication | Highest across consumers | Lowest | Moderate |
| False impression of project endorsement | Low | Highest | Explicit and reviewable |

## Approved implementation direction

Generic `install-script` execution is deferred. Pinning the first-stage script authenticates only that script's bytes; it does not authenticate a mutable binary, second-stage script, package or `latest` release that the script subsequently downloads. Establishing transitive integrity would require auditing and constraining each upstream script's complete network and execution behaviour, which is no longer meaningfully generic.

The approved implementation is instead a narrow `github-release` installer that:

- selects one public repository, exact release tag and exact raw executable asset;
- requires a caller-pinned SHA-256 digest over the downloaded executable;
- follows only bounded HTTPS redirects into a unique temporary directory;
- installs one verified file to an explicit absolute destination with mode `0755` and `root:root` ownership;
- is idempotent only when destination content, mode and ownership already match; and
- rejects `latest`, archive extraction, arbitrary commands, authenticated downloads and conflicting destinations.

Brave Search CLI is the representative composition because it publishes a raw `linux/amd64` GitHub Release executable even though its quick-start documentation promotes a mutable bootstrap script. Installing the executable directly removes that unverified execution stage.

The expert-developer audience remains relevant: the caller owns repository identity, exact version, asset selection and digest review. The installer owns deterministic enforcement and does not claim that a matching digest proves the selected upstream program is benign.

Any future script executor or unverified mode requires a separate reviewed decision and is not needed to complete this milestone.

## Candidate integrity and execution contract

If implementation evidence later supports a generic or semi-generic installer, its secure path should require all of the following:

- exactly one HTTPS source URL without embedded credentials;
- exactly one full lowercase or uppercase SHA-256 value, normalised only for comparison;
- bounded HTTPS-only redirects with the effective URL reported without query credentials;
- a unique mode-restricted temporary directory and an `EXIT` cleanup trap;
- download to a regular file, non-empty check and digest verification before execution;
- a fixed Bash interpreter unless a tool-specific contract approves another interpreter;
- repeatable `--argument` values passed literally, including empty values and values beginning with `-`;
- optional repeatable `--environment NAME=VALUE` assignments parsed literally, with validated names and documentation that ordinary values must not contain secrets;
- no command strings, splitting, globbing, expansion, `eval` or `sh -c`;
- explicit documentation that the script receives the executing process's authority and network access;
- validation of all installer-owned inputs and prerequisites before download or state changes; and
- fail-closed fetch, verification and execution handling with no unverified fallback.

The expected digest is public integrity metadata, not a secret. Authentication credentials must not be accepted in the URL or ordinary installer options.

## Environment and secret handling decision

The expert-developer audience and common upstream installer interfaces justify literal arguments and non-secret environment assignments. A candidate generic interface may therefore provide repeatable `--argument VALUE` and `--environment NAME=VALUE` options. Each occurrence is one literal array element: the installer validates the environment name, performs no splitting or expansion and invokes the downloaded script through `env -- "${environment[@]}" bash -- "$script" "${arguments[@]}"`. This reproduces the useful part of the predecessor without reproducing its shell evaluation.

For simple fixed values, assignment at the Dockerfile invocation site remains clearer:

```dockerfile
RUN TOOL_INSTALL_DIR=/usr/local/bin \
    /opt/ubuntu-devcontainer-installers/installers/example/install.sh
```

Neither form is suitable for secrets embedded in Dockerfile text. Secrets must be supplied by the consuming Dockerfile through BuildKit secret mounts, not `ARG`, `ENV`, URL query parameters or installer command-line values. Docker documents that `ARG` and `ENV` persist in image metadata and recommends `RUN --mount=type=secret`. A mounted secret can be exposed directly to the remote process as a file or BuildKit-mounted environment variable without passing its value through the installer CLI. Any supported secret path or environment name must be tool-specific, must not reveal the value and must warn that the executed script can read and exfiltrate the deliberately exposed secret.

## Supplementary third-party assessment

Third-party services can add evidence but cannot replace content authentication or provenance verification:

- **GitHub artifact attestations** can provide cryptographically verifiable provenance for GitHub release binaries when the publisher generated an attestation. `gh attestation verify` can bind the downloaded artifact to an expected repository, owner, signer repository or signer workflow. This is materially stronger than relying on a release URL alone, but the consumer must still decide which repository, workflow and GitHub trust root are acceptable. Verification would also add the GitHub CLI or another verifier as a prerequisite, so it belongs in a tool-specific design unless repeated use justifies shared support.
- **Upstream signatures or SLSA provenance** can bind a digest to an expected signer, source and builder. They are preferred where available and where the project can pin an independent identity policy. Merely downloading an attestation beside the artifact is insufficient; its signature, artifact subject and expected identity must all be verified.
- **VirusTotal or comparable multi-engine scanning** can provide malware detections, reputation and sandbox observations for a known hash. A clean result is not proof of origin, source review or benign behaviour, can be a false negative and says little about a bootstrap script that downloads mutable second-stage content. Public upload may disclose files; VirusTotal's private scanning requires a separate licensed service. It should be optional release-review evidence, not a build-time dependency or secure-path gate, and adopting it would require prior approval under the project's no-new-services rule.
- **OpenSSF Scorecard and vulnerability data** can inform whether an upstream project and workflow deserve trust. They assess project practices and known issues rather than authenticating the particular bytes being executed.

A useful evidence hierarchy is: mechanically verified artifact identity first; verified signer, source and builder provenance where available; human source and release review; then supplementary reputation, malware scanning and project-health signals. Independent signals can raise confidence, but they must not be collapsed into a claim that the artifact is safe.

## Comparison with mise-style automation

Mise does not reduce all tool installation to a generic remote-script executor. It uses backend-specific knowledge to separate version discovery, artifact selection, verification, installation and activation:

- core and ecosystem backends understand their release channels;
- the `github`, `gitlab`, `http` and Aqua backends can record resolved artifact URLs, checksums and sizes in `mise.lock`;
- `mise install --locked` consumes locked metadata and fails when required lock information is absent;
- the Aqua registry supplies reviewed package metadata and supports checksums, signatures and GitHub artifact-attestation policies; and
- the GitHub backend can verify artifact attestations, with an explicit per-tool option required to disable that check where it applies.

This is closer to a package manager plus a reviewed metadata registry than to `curl | sh`. Its automation works because a backend or registry knows how a tool names versions, maps operating systems and architectures to assets, verifies releases and exposes commands. The lockfile separates a convenient request such as major version or `latest` from the exact URL and checksum subsequently installed.

The analogous project design would have two layers:

1. **Now:** install an exact caller-selected GitHub Release asset with a caller-pinned digest. The consuming Dockerfile owns the exact repository, tag, asset and digest, so updates are explicit reviewed changes.
2. **Later, only if demonstrated:** add an update-time resolver that selects an architecture-specific asset, verifies publisher attestations or checksums and emits project-owned lock metadata. That is a distinct product capability, not dynamic version selection during installation.

Adopting mise itself would add a dependency and a much broader tool-management lifecycle, so it is not proposed. Querying GitHub dynamically during every image build would also reduce reproducibility. Mise's useful pattern for this project is resolution during an explicit update operation followed by locked, offline-capable or deterministic installation—not LLM-driven selection during the build.

## LLM-assisted analysis and version selection

An LLM may assist an expert reviewer by summarising a pinned script, comparing two pinned versions, identifying suspicious commands, mapping downloads and side effects, or drafting a review checklist. The analyzed input and model output should be recorded against the exact SHA-256 digest so that later byte changes invalidate the review.

LLM output is not an integrity mechanism, provenance proof or autonomous version-selection authority. Models can miss obfuscated or staged behaviour, hallucinate guarantees, vary between runs and be influenced by instructions embedded in the analyzed source. A recommendation such as “use the latest safe version” is mutable and not reproducible. The acceptable pattern is:

1. deterministically enumerate candidate releases from an authenticated upstream identity;
2. select an exact release through explicit policy and expert review;
3. download and mechanically verify the exact artifact, signature or attestation;
4. optionally use LLM analysis as recorded advisory evidence; and
5. pin the resulting digest and provenance policy in code and tests.

Automated update tooling may open a proposed digest change with source, provenance, scan and LLM-review evidence, but it must not silently move the production pin. The expert user or reviewed repository change remains the trust decision.

## Controlled-risk boundary

An unverified execution mode is not approved by this investigation. If a demonstrated development-only tool cannot provide stable verifiable content and implementation is still considered worthwhile, review must first define a specific `--allow-unverified-script`-style option and satisfy the project's controlled-risk policy. The warning immediately before execution would need to state that mutable remote code will execute with build-step authority, identify likely image and secret compromise consequences, and advise pinning reviewed bytes by SHA-256 or using a package or tool-specific installer instead.

The option could waive only content verification. It must not waive TLS checks, permit credentials in URLs, enable shell evaluation, weaken cleanup or become an automatic fallback after digest failure.

## Direct Dockerfile example boundary

The following fragment illustrates the security distinction; it is not yet a recommendation for a particular tool:

```dockerfile
# Downloads bytes whose reviewed digest is owned by this Dockerfile
ADD --checksum=sha256:<reviewed-digest> \
    https://example.invalid/releases/install.sh \
    /tmp/example-install.sh

# Executes only the digest-verified file with explicit authority and arguments
RUN bash /tmp/example-install.sh --literal-argument \
    && rm -f /tmp/example-install.sh
```

This is more auditable than an unverified pipeline, but it still grants the reviewed script full root authority in that build step. A multi-stage build can reduce which resulting files enter the final image, but it does not sandbox the script from the builder while the stage runs.

## Remaining investigation

The approved implementation work is:

1. implement and document the narrow raw-executable `github-release` contract;
2. test exact input validation, digest failure, installation, idempotency, destination collision and unsupported-platform rejection;
3. qualify Brave Search CLI through its exact `linux/amd64` release asset and reviewed digest;
4. add packaged-artefact coverage;
5. record update-time provenance or attestation automation as possible later work; and
6. review any future script executor or controlled-risk exception separately.

## References

- [Docker build input policies and `ADD --checksum`](https://docs.docker.com/build/policies/)
- [Dockerfile `ADD --checksum` reference](https://docs.docker.com/reference/dockerfile/#add---checksum)
- [Docker build secrets](https://docs.docker.com/build/building/secrets/)
- [Docker check for secrets in `ARG` or `ENV`](https://docs.docker.com/reference/build-checks/secrets-used-in-arg-or-env/)
- [GitHub artifact attestation verification](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)
- [mise lockfiles](https://mise.jdx.dev/dev-tools/mise-lock.html)
- [mise backend architecture](https://mise.jdx.dev/dev-tools/backend-architecture.html)
- [mise Aqua backend](https://mise.jdx.dev/dev-tools/backends/aqua.html)
- [VirusTotal API overview](https://docs.virustotal.com/reference/getting-started)
- [VirusTotal private scanning](https://docs.virustotal.com/reference/private-files)
- [OpenSSF Scorecard](https://scorecard.dev/)
- [curl redirect and credential behaviour](https://curl.se/docs/manpage.html#-L)
- [SLSA artifact verification](https://slsa.dev/spec/draft/verifying-artifacts)
- [Project security and controlled-risk requirements](../PROJECT.md#26-security-requirements)
- [Project network download conventions](../CONVENTIONS.md#network-downloads-and-integrity)
