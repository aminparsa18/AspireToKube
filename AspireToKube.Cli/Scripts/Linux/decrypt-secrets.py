#!/usr/bin/env python3

"""
Decrypt secrets from aspirate-state.json using AES-GCM

This script replicates the C# secret management behavior from Aspirate.

Aspirate Secret Management (from SecretProvider.cs):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Salt Generation:
   - Random 12-byte salt created on first use
   - Base64-encoded and stored in aspirate-state.json (secrets.salt)
   - Salt is Base64-decoded before use in PBKDF2

2. Key Derivation:
   - Uses PBKDF2 (Rfc2898DeriveBytes) with SHA-256
   - Iterations: 1,000,000 (one million)
   - Output: 32-byte key for AES-256
   - The derived key IS the hash stored in aspirate-state.json

3. Password Verification:
   - Hash in JSON = Base64(PBKDF2(password, salt, 1M iterations))
   - To verify: derive key from password and compare with stored hash
   - The hash and encryption key are the SAME 32 bytes

4. Why Hash Changes:
   - Each time aspirate creates new secrets, it generates a NEW random salt
   - Same password + different salt = different hash
   - This is normal and expected behavior

5. Encryption Format:
   - Algorithm: AES-256-GCM
   - Nonce: 12 bytes (the same salt used in PBKDF2)
   - Tag: 16 bytes (authentication tag)
   - Structure: Base64([nonce][tag][ciphertext])

6. Decryption:
   - Derive key from password + Base64-decoded salt
   - Extract nonce, tag, and ciphertext from Base64
   - Decrypt with AES-GCM
   - Return UTF-8 decoded plaintext
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""

import sys
import json
import base64
import hashlib
import getpass
from pathlib import Path

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.backends import default_backend
except ImportError:
    print("\033[0;31mError: cryptography library is required but not installed.\033[0m")
    print("\033[1;33mPlease run the init command first:\033[0m")
    print("\033[0;36m  aspire2kube init --distro <your-distribution>\033[0m")
    print()
    sys.exit(1)

# Color codes
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'
NC = '\033[0m'

def print_color(color, message):
    print(f"{color}{message}{NC}")

def derive_key_from_password(password: str, salt_b64: str) -> bytes:
    """
    Derive a 32-byte AES-256 key from password and salt.
    Uses PBKDF2 with SHA-256 and 1,000,000 iterations to match C# implementation.
    
    IMPORTANT: The salt in aspirate-state.json is Base64-encoded!
    """
    # Decode the Base64-encoded salt
    salt_bytes = base64.b64decode(salt_b64)
    
    # Use PBKDF2 with SHA-256 to derive the key
    # CRITICAL: Must use 1,000,000 iterations to match C# Rfc2898DeriveBytes
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,  # 256 bits for AES-256
        salt=salt_bytes,
        iterations=1000000,  # 1 million iterations (matches C# implementation)
        backend=default_backend()
    )
    
    return kdf.derive(password.encode('utf-8'))

def verify_password(password: str, salt_b64: str, expected_hash_b64: str) -> bool:
    """
    Verify the password by comparing the derived key with the stored hash.
    
    In Aspirate, the "hash" is actually the 32-byte derived key from PBKDF2,
    Base64-encoded. This is the same key used for encryption.
    """
    try:
        # Derive the key from the password
        derived_key = derive_key_from_password(password, salt_b64)
        
        # The hash in aspirate-state.json is the Base64-encoded derived key
        expected_key = base64.b64decode(expected_hash_b64)
        
        # Compare the keys
        return derived_key == expected_key
    except Exception:
        return False

def decrypt_value(ciphertext_b64: str, key: bytes, tag_size: int = 16) -> str:
    """
    Decrypt a value using AES-GCM.
    
    The ciphertext format (from C# AesGcmCrypter):
    Base64([nonce (12 bytes)][tag (tag_size bytes)][ciphertext])
    
    Parameters:
    - ciphertext_b64: Base64-encoded encrypted data
    - key: 32-byte AES-256 key
    - tag_size: Authentication tag size in bytes (default: 16, which is 128 bits)
    
    The C# code structure:
    1. Prepends 12-byte nonce (salt) to the result
    2. Appends tag_size bytes for authentication
    3. Appends the actual ciphertext
    4. Base64 encodes the entire thing
    """
    try:
        # Decode base64
        encrypted_data = base64.b64decode(ciphertext_b64)
        
        # Extract components based on C# AesGcmCrypter structure
        nonce_size = 12  # Fixed 12 bytes as per C# requirement
        nonce = encrypted_data[:nonce_size]
        tag = encrypted_data[nonce_size:nonce_size + tag_size]
        ciphertext = encrypted_data[nonce_size + tag_size:]
        
        # Python's AESGCM expects ciphertext + tag concatenated
        ciphertext_with_tag = ciphertext + tag
        
        # Decrypt using AES-GCM
        aesgcm = AESGCM(key)
        plaintext = aesgcm.decrypt(nonce, ciphertext_with_tag, None)
        
        return plaintext.decode('utf-8')
    except Exception as e:
        raise ValueError(f"Decryption failed: {str(e)}")

def main():
    print("=" * 48)
    print("  Aspirate Secrets Decryption")
    print("=" * 48)
    print()
    
    # Check for aspirate-state.json
    state_file = Path("aspirate-state.json")
    if not state_file.exists():
        print_color(RED, "Error: aspirate-state.json not found in current directory.")
        sys.exit(1)
    
    # Load state file
    with open(state_file, 'r') as f:
        state = json.load(f)
    
    # Extract salt and hash
    secrets_config = state.get('secrets', {})
    salt = secrets_config.get('salt')
    expected_hash = secrets_config.get('hash')
    
    if not salt:
        print_color(RED, "Error: No salt found in aspirate-state.json")
        sys.exit(1)
    
    if not expected_hash:
        print_color(RED, "Error: No hash found in aspirate-state.json")
        sys.exit(1)
    
    print_color(CYAN, f"Salt found: {salt}")
    print_color(CYAN, f"Hash found: {expected_hash[:20]}...")
    print()
    
    # Prompt for master password
    print_color(YELLOW, "Enter the master password to decrypt secrets:")
    master_password = getpass.getpass("Password: ")
    print()
    
    if not master_password:
        print_color(RED, "Error: Password cannot be empty")
        sys.exit(1)
    
    # Verify password using Aspirate's method
    # The hash is actually the Base64-encoded derived key
    if not verify_password(master_password, salt, expected_hash):
        print_color(RED, "Error: Incorrect password.")
        print_color(YELLOW, "The derived key does not match the stored hash.")
        sys.exit(1)
    
    print_color(GREEN, "Password verified!")
    print()
    
    # Derive encryption key (same as the hash verification)
    try:
        key = derive_key_from_password(master_password, salt)
        print_color(GREEN, "Encryption key derived successfully")
        print()
    except Exception as e:
        print_color(RED, f"Error: Failed to derive encryption key: {e}")
        sys.exit(1)
    
    # Check for manifests directory
    manifests_dir = Path("manifests")
    if not manifests_dir.exists():
        print_color(YELLOW, "Warning: manifests/ directory not found")
        return
    
    # Get all services with secrets
    all_secrets = secrets_config.get('secrets', {})
    
    if not all_secrets:
        print_color(YELLOW, "No services with secrets found")
        return
    
    print_color(CYAN, "Decrypting secrets...")
    print()
    
    decrypted_count = 0
    failed_count = 0
    
    for service_name, service_secrets in all_secrets.items():
        service_dir = manifests_dir / service_name
        
        # Skip if directory doesn't exist
        if not service_dir.exists():
            continue
        
        # Skip if no secrets defined
        if not service_secrets or not isinstance(service_secrets, dict):
            continue
        
        secret_file = service_dir / f".{service_name}.secrets"
        
        print_color(YELLOW, f"Processing {service_name}...")
        
        # Create or overwrite the secret file
        with open(secret_file, 'w') as f:
            for secret_key, encrypted_value in service_secrets.items():
                print(f"  Decrypting {secret_key}... ", end='', flush=True)
                
                try:
                    decrypted_value = decrypt_value(encrypted_value, key)
                    f.write(f"{secret_key}={decrypted_value}\n")
                    print_color(GREEN, "✓")
                    decrypted_count += 1
                except Exception as e:
                    print_color(RED, f"✗ (failed: {str(e)})")
                    # Keep encrypted value as fallback
                    f.write(f"{secret_key}={encrypted_value}\n")
                    failed_count += 1
        
        # Set secure permissions (owner read/write only)
        secret_file.chmod(0o600)
        print()
    
    print("=" * 48)
    print("  Decryption Summary")
    print("=" * 48)
    print()
    print_color(GREEN, f"Successfully decrypted: {decrypted_count}")
    if failed_count > 0:
        print_color(RED, f"Failed to decrypt: {failed_count}")
        print_color(YELLOW, "(Failed secrets kept as encrypted values)")
    print()
    print_color(GREEN, "Decryption complete!")
    print_color(YELLOW, "Secret files are ready in manifests/*/.{service}.secrets")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        print_color(YELLOW, "Operation cancelled by user")
        sys.exit(130)
    except Exception as e:
        print()
        print_color(RED, f"Unexpected error: {str(e)}")
        sys.exit(1)