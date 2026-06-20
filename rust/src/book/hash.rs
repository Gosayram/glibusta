use sha2::{Digest, Sha256};

pub(crate) fn sha256_hex(bytes: &[u8]) -> String {
    let result = Sha256::new_with_prefix(bytes).finalize();
    result.iter().map(|b| format!("{:02x}", b)).collect()
}
