# TF Provider Scanning

This repository contains tooling to download HashiCorp Terraform providers (binary + source), verify their checksums and signatures, and run a set of static and binary scanners against them.

## Prerequisites

Install the following tools before running `download-verify.sh` (macOS examples shown where appropriate):

- curl (usually installed)
- GNU coreutils (for `sha256sum`) or `shasum` (macOS has `shasum`)
- GnuPG (`gpg`) to verify signed checksum files
- p7zip (`7z`) to extract zip files
- grype (binary vulnerability scanner)
- govulncheck (Go vulnerability scanner)
- gitleaks (secrets scanner)

On macOS you can install most prerequisites with Homebrew:

```bash
# example (install only what you need)
brew install gpg p7zip grype govulncheck gitleaks coreutils
```

Note: Installing `coreutils` provides `sha256sum` as `gsha256sum` on macOS; the script will fall back to `shasum` if `sha256sum` is not available.

## Quickstart / Usage

Run the script from the repository root:

```bash
./download-verify.sh <provider-name> <version>
# examples
./download-verify.sh random 3.7.2
./download-verify.sh aws 6.13.0
```

The script expects two arguments: provider name (for example `aws` or `random`) and the provider version (for example `6.13.0` or `3.7.2`). It currently targets the `linux_amd64` platform by default.

## What `download-verify.sh` does

High-level flow:

1. Download provider release artifacts from HashiCorp releases:
   - provider zip (binary for `linux_amd64`)
   - SHA256SUMS and SHA256SUMS.sig files
2. Verify the binary checksum using `sha256sum` or `shasum`.
3. Verify the GPG signature of the SUMS file using `gpg --verify`.
4. Unzip the provider archive to the `download/` directory.
5. Copy the provider binary (an x5 archive) into `release/<provider>/<version>/linux_amd64/`.
6. Scan the provider binary with `grype` (container/binary vulnerability scanning) and `govulncheck` in binary mode.
7. Download the provider source code from the provider's GitHub repository (tag zip) and unpack it to `download/`.
8. Scan the source tree with `govulncheck` (source mode) and `gitleaks` for potential secrets.

The script is intentionally permissive: many checks are best-effort and will continue on failures so you can inspect results rather than abort on the first issue.

## Output locations

- `download/<provider>/<version>/` — downloaded artifacts and extracted source
- `release/<provider>/<version>/linux_amd64/` — provider x5 binary copied here and scanned

Scanner outputs are printed to stdout. The script uses `|| true` on most scanner invocations so exit status will not stop the script if a scanner fails or finds issues.

## Example

Download and verify the `random` provider v3.7.2:

`./download-verify.sh random 3.7.2`

```bash
==> Downloading Terraform provider files: random version 3.7.2 for linux_amd64
==> Verifying checksum...
terraform-provider-random_3.7.2_linux_amd64.zip: OK
==> Verifying GPG signature...
gpg: Signature made Tue Apr 22 06:16:00 2025 CDT
gpg:                using RSA key 374EC75B485913604A831CC7C820C6D5CD27AB87
gpg: Good signature from "HashiCorp Security (hashicorp.com/security) <security@hashicorp.com>" [unknown]
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: C874 011F 0AB4 0511 0D02  1055 3436 5D94 72D7 468F
     Subkey fingerprint: 374E C75B 4859 1360 4A83  1CC7 C820 C6D5 CD27 AB87
==> Unzipping provider...

7-Zip [64] 17.05 : Copyright (c) 1999-2021 Igor Pavlov : 2017-08-28
p7zip Version 17.05 (locale=utf8,Utf16=on,HugeFiles=on,64 bits,8 CPUs LE)

Scanning the drive for archives:
1 file, 5817019 bytes (5681 KiB)

Extracting archive: download/random/3.7.2/terraform-provider-random_3.7.2_linux_amd64.zip
--
Path = download/random/3.7.2/terraform-provider-random_3.7.2_linux_amd64.zip
Type = zip
Physical Size = 5817019

Everything is Ok

Files: 2
Size:       15680017
Compressed: 5817019
--> Copying terraform-provider-random_v3.7.2_x5 to download/random/3.7.2
==> Scanning for provider files (grype)...
 ✔ Indexed file system                                                                          release/random/3.7.2/linux_amd64/terraform-provider-random_v3.7.2_x5 
 ✔ Cataloged contents                                                                               b8e5451ef4c65a4d0ccb678b3c0b27ce756d8f9ddf1ca43bbce1fa4efe5fa19e 
   ├── ✔ Packages                        [27 packages]  
   ├── ✔ Executables                     [1 executables]  
   ├── ✔ File digests                    [1 files]  
   └── ✔ File metadata                   [1 locations]  
 ✔ Scanned for vulnerabilities     [5 vulnerability matches]  
   ├── by severity: 1 critical, 2 high, 2 medium, 0 low, 0 negligible
NAME    INSTALLED  FIXED IN         TYPE       VULNERABILITY   SEVERITY  EPSS           RISK   
stdlib  go1.23.7   1.23.12, 1.24.6  go-module  CVE-2025-47907  High      < 0.1% (18th)  < 0.1  
stdlib  go1.23.7   1.23.8, 1.24.2   go-module  CVE-2025-22871  Critical  < 0.1% (1st)   < 0.1  
stdlib  go1.23.7   1.23.10, 1.24.4  go-module  CVE-2025-4673   Medium    < 0.1% (3rd)   < 0.1  
stdlib  go1.23.7   1.23.10, 1.24.4  go-module  CVE-2025-0913   Medium    < 0.1% (1st)   < 0.1  
stdlib  go1.23.7   1.23.11, 1.24.5  go-module  CVE-2025-4674   High      < 0.1% (0th)   < 0.1
==> Scanning for provider files (govulncheck)...
=== Symbol Results ===

Vulnerability #1: GO-2025-3849
    Incorrect results returned from Rows.Scan in database/sql
  More info: https://pkg.go.dev/vuln/GO-2025-3849
  Standard library
    Found in: database/sql@go1.23.7
    Fixed in: database/sql@go1.23.12
    Vulnerable symbols found:
      #1: sql.Row.Scan
      #2: sql.Rows.Scan

Vulnerability #2: GO-2025-3751
    Sensitive headers not cleared on cross-origin redirect in net/http
  More info: https://pkg.go.dev/vuln/GO-2025-3751
  Standard library
    Found in: net/http@go1.23.7
    Fixed in: net/http@go1.23.10
    Vulnerable symbols found:
      #1: http.Client.Do
      #2: http.Client.Get
      #3: http.Client.Head
      #4: http.Client.Post
      #5: http.Client.PostForm
      Use '-show traces' to see the other 4 found symbols

Vulnerability #3: GO-2025-3563
    Request smuggling due to acceptance of invalid chunked data in net/http
  More info: https://pkg.go.dev/vuln/GO-2025-3563
  Standard library
    Found in: net/http/internal@go1.23.7
    Fixed in: net/http/internal@go1.23.8
    Vulnerable symbols found:
      #1: internal.chunkedReader.Read

Your code is affected by 3 vulnerabilities from the Go standard library.
This scan found no other vulnerabilities in packages you import or modules you
require.
Use '-show verbose' for more details.
==> Downloading repository source...
--> Unzipping code...

7-Zip [64] 17.05 : Copyright (c) 1999-2021 Igor Pavlov : 2017-08-28
p7zip Version 17.05 (locale=utf8,Utf16=on,HugeFiles=on,64 bits,8 CPUs LE)

Scanning the drive for archives:
1 file, 216271 bytes (212 KiB)

Extracting archive: download/random/3.7.2/v3.7.2.zip
--
Path = download/random/3.7.2/v3.7.2.zip
Type = zip
Physical Size = 216271
Comment = bc2ddb552b4676d16997987a9bf2875c7b98d342

Everything is Ok

Folders: 45
Files: 136
Size:       819275
Compressed: 216271
==> Scanning source code for vulnerabilities...
No vulnerabilities found.
==> Scanning source code for secrets...

    ○
    │╲
    │ ○
    ○ ░
    ░    gitleaks

1:31PM INF scanned ~725430 bytes (725.43 KB) in 80.5ms
1:31PM INF no leaks found
✔  All done!
```

## References

- HashiCorp releases: https://releases.hashicorp.com/
- grype (Anchore): https://github.com/anchore/grype
- govulncheck (Go): https://go.dev/security/vuln/govulncheck
- gitleaks: https://github.com/zricethezav/gitleaks
- p7zip / 7-Zip: https://www.7-zip.org/ (or https://formulae.brew.sh/formula/p7zip for Homebrew)
