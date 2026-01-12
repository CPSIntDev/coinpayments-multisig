use anyhow::{anyhow, Context, Result};
use clap::{Parser, Subcommand};
use rand::rngs::OsRng;
use secp256k1::{Message, Secp256k1, SecretKey};
use serde::{Deserialize, Serialize};
use sha3::{Digest, Keccak256};
use std::fs;
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "tron-utils")]
#[command(about = "TRON contract deployment and interaction utilities")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate a new private key and TRON address
    GenerateKey {
        /// Output as JSON
        #[arg(long, default_value = "false")]
        json: bool,
    },

    /// Deploy the USDTMultisig contract
    Deploy {
        /// TRON RPC URL (e.g., https://api.trongrid.io)
        #[arg(long)]
        rpc_url: String,

        /// Private key (hex, with or without 0x prefix)
        #[arg(long)]
        private_key: String,

        /// USDT token address (TRON base58 format, e.g., TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t)
        #[arg(long)]
        usdt: String,

        /// Owner addresses (comma-separated TRON base58 addresses)
        #[arg(long)]
        owners: String,

        /// Required approval threshold
        #[arg(long)]
        threshold: u64,

        /// Path to compiled contract JSON (from forge build)
        #[arg(long, default_value = "../out/Multisig.sol/USDTMultisig.json")]
        contract_json: PathBuf,

        /// Fee limit in SUN (default: 1000 TRX = 1,000,000,000 SUN)
        #[arg(long, default_value = "1000000000")]
        fee_limit: u64,
    },

    /// Convert private key to TRON address
    Address {
        /// Private key (hex, with or without 0x prefix)
        #[arg(long)]
        private_key: String,
    },

    /// Convert hex address to TRON base58 address
    ToBase58 {
        /// Hex address (with or without 0x prefix)
        #[arg(long)]
        hex: String,
    },

    /// Convert TRON base58 address to hex
    ToHex {
        /// TRON base58 address
        #[arg(long)]
        address: String,
    },
}

#[derive(Debug, Deserialize)]
struct ContractJson {
    bytecode: BytecodeObject,
}

#[derive(Debug, Deserialize)]
struct BytecodeObject {
    object: String,
}

#[derive(Debug, Serialize)]
struct DeployContractRequest {
    owner_address: String,
    fee_limit: u64,
    call_value: u64,
    consume_user_resource_percent: u64,
    origin_energy_limit: u64,
    abi: String,
    bytecode: String,
    parameter: String,
    name: String,
}

#[derive(Debug, Deserialize)]
struct BroadcastResponse {
    result: Option<bool>,
    #[allow(dead_code)]
    txid: Option<String>,
    code: Option<String>,
    message: Option<String>,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::GenerateKey { json } => {
            generate_private_key(json)?;
        }
        Commands::Deploy {
            rpc_url,
            private_key,
            usdt,
            owners,
            threshold,
            contract_json,
            fee_limit,
        } => {
            deploy_contract(
                &rpc_url,
                &private_key,
                &usdt,
                &owners,
                threshold,
                &contract_json,
                fee_limit,
            )
            .await?;
        }
        Commands::Address { private_key } => {
            let address = private_key_to_tron_address(&private_key)?;
            println!("TRON Address: {}", address);
        }
        Commands::ToBase58 { hex } => {
            let address = hex_to_tron_address(&hex)?;
            println!("TRON Address: {}", address);
        }
        Commands::ToHex { address } => {
            let hex = tron_address_to_hex(&address)?;
            println!("Hex: {}", hex);
        }
    }

    Ok(())
}

fn generate_private_key(json_output: bool) -> Result<()> {
    let secp = Secp256k1::new();
    let (secret_key, _public_key) = secp.generate_keypair(&mut OsRng);
    
    let private_key_hex = hex::encode(secret_key.secret_bytes());
    let address = private_key_to_tron_address(&private_key_hex)?;
    
    if json_output {
        let output = serde_json::json!({
            "privateKey": private_key_hex,
            "address": address
        });
        println!("{}", serde_json::to_string_pretty(&output)?);
    } else {
        println!("🔑 New TRON Wallet Generated");
        println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        println!("Private Key: {}", private_key_hex);
        println!("Address:     {}", address);
        println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        println!("\n⚠️  IMPORTANT: Save your private key securely! Never share it!");
    }
    
    Ok(())
}

async fn deploy_contract(
    rpc_url: &str,
    private_key: &str,
    usdt: &str,
    owners: &str,
    threshold: u64,
    contract_json: &PathBuf,
    fee_limit: u64,
) -> Result<()> {
    println!("🚀 Deploying USDTMultisig contract to TRON...\n");

    // Parse private key and get deployer address
    let deployer = private_key_to_tron_address(private_key)?;
    println!("Deployer: {}", deployer);

    // Parse owners
    let owner_list: Vec<&str> = owners.split(',').map(|s| s.trim()).collect();
    println!("Owners: {:?}", owner_list);
    println!("Threshold: {}", threshold);
    println!("USDT: {}", usdt);

    // Validate threshold
    if threshold == 0 || threshold as usize > owner_list.len() {
        return Err(anyhow!(
            "Invalid threshold: must be > 0 and <= number of owners"
        ));
    }

    // Load contract bytecode
    let contract_data = fs::read_to_string(contract_json)
        .with_context(|| format!("Failed to read contract JSON: {:?}", contract_json))?;
    let contract: ContractJson =
        serde_json::from_str(&contract_data).context("Failed to parse contract JSON")?;
    let bytecode = &contract.bytecode.object;
    println!("Bytecode length: {} bytes", bytecode.len() / 2);

    // Encode constructor parameters
    let params = encode_constructor_params(usdt, &owner_list, threshold)?;
    println!("Constructor params: {}", params);

    // Contract ABI (simplified for deployment)
    let abi = get_contract_abi();

    // Build deploy request
    let deployer_hex = tron_address_to_hex(&deployer)?;
    let request = DeployContractRequest {
        owner_address: deployer_hex.clone(),
        fee_limit,
        call_value: 0,
        consume_user_resource_percent: 100,
        origin_energy_limit: 10000000,
        abi: abi.to_string(),
        bytecode: bytecode.clone(),
        parameter: params,
        name: "USDTMultisig".to_string(),
    };

    println!("\n📡 Creating deployment transaction...");

    // Create deployment transaction
    let client = reqwest::Client::new();
    let response_text = client
        .post(format!("{}/wallet/deploycontract", rpc_url))
        .json(&request)
        .send()
        .await?
        .text()
        .await?;

    // Parse response
    let response: serde_json::Value = serde_json::from_str(&response_text)
        .with_context(|| format!("Failed to parse response: {}", response_text))?;

    // Check for errors in response
    if let Some(result) = response.get("result") {
        if result.get("result") == Some(&serde_json::json!(false)) {
            let msg = result
                .get("message")
                .and_then(|m| m.as_str())
                .map(|m| decode_hex_message(m))
                .unwrap_or_else(|| "Unknown error".to_string());
            return Err(anyhow!("Failed to create transaction: {}", msg));
        }
    }

    // Check for Error field (some API versions use this)
    if let Some(error) = response.get("Error") {
        return Err(anyhow!("API Error: {}", error));
    }

    // TRON API returns transaction fields at root level (txID, raw_data, etc.)
    // NOT nested under a "transaction" key
    let transaction = if response.get("transaction").is_some() {
        response.get("transaction").cloned().unwrap()
    } else if response.get("txID").is_some() {
        // Transaction fields are at root level
        response.clone()
    } else {
        return Err(anyhow!("No transaction in response. Full response:\n{}", 
            serde_json::to_string_pretty(&response).unwrap_or_default()));
    };

    let tx_id = transaction
        .get("txID")
        .and_then(|v| v.as_str())
        .map(String::from)
        .ok_or_else(|| anyhow!("No txID in response"))?;

    println!("Transaction ID: {}", tx_id);

    // Sign transaction
    println!("\n🔐 Signing transaction...");
    let signature = sign_transaction(&tx_id, private_key)?;

    // Add signature to transaction
    let mut signed_tx = transaction.clone();
    signed_tx
        .as_object_mut()
        .ok_or_else(|| anyhow!("Transaction is not an object"))?
        .insert("signature".to_string(), serde_json::json!([signature]));

    // Broadcast transaction
    println!("📤 Broadcasting transaction...");
    let broadcast_response = client
        .post(format!("{}/wallet/broadcasttransaction", rpc_url))
        .json(&signed_tx)
        .send()
        .await?
        .json::<BroadcastResponse>()
        .await?;

    if broadcast_response.result != Some(true) {
        let code = broadcast_response.code.unwrap_or_default();
        let msg = broadcast_response
            .message
            .map(|m| decode_hex_message(&m))
            .unwrap_or_else(|| "Unknown error".to_string());
        return Err(anyhow!("Broadcast failed [{}]: {}", code, msg));
    }

    // Get contract address from response
    let contract_address = response
        .get("contract_address")
        .and_then(|v| v.as_str())
        .map(|hex| {
            // Convert hex address (41...) to base58
            hex_to_tron_address(hex).unwrap_or_else(|_| hex.to_string())
        })
        .unwrap_or_else(|| "(Check TronScan for contract address)".to_string());

    println!("\n✅ Contract deployed successfully!");
    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    println!("Transaction: {}", tx_id);
    println!("Contract:    {}", contract_address);
    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    println!("\nView on TronScan: https://nile.tronscan.org/#/transaction/{}", tx_id);

    Ok(())
}

fn private_key_to_tron_address(private_key: &str) -> Result<String> {
    let key_hex = private_key.trim_start_matches("0x");
    let key_bytes = hex::decode(key_hex).context("Invalid private key hex")?;

    let secp = Secp256k1::new();
    let secret_key = SecretKey::from_slice(&key_bytes).context("Invalid private key")?;
    let public_key = secret_key.public_key(&secp);

    // Get uncompressed public key (65 bytes: 04 + x + y)
    let pub_key_bytes = public_key.serialize_uncompressed();

    // Keccak256 hash of public key (skip first byte 0x04)
    let mut hasher = Keccak256::new();
    hasher.update(&pub_key_bytes[1..]);
    let hash = hasher.finalize();

    // Take last 20 bytes and add 0x41 prefix (TRON mainnet)
    let mut address_bytes = vec![0x41];
    address_bytes.extend_from_slice(&hash[12..]);

    // Base58Check encode
    Ok(bs58_check_encode(&address_bytes))
}

fn tron_address_to_hex(address: &str) -> Result<String> {
    let bytes = bs58_check_decode(address)?;
    Ok(hex::encode(&bytes))
}

fn hex_to_tron_address(hex_addr: &str) -> Result<String> {
    let clean_hex = hex_addr.trim_start_matches("0x");
    let bytes = hex::decode(clean_hex).context("Invalid hex")?;
    Ok(bs58_check_encode(&bytes))
}

fn bs58_check_encode(data: &[u8]) -> String {
    // Double SHA256 for checksum
    let hash1 = sha256(data);
    let hash2 = sha256(&hash1);
    let checksum = &hash2[0..4];

    let mut with_checksum = data.to_vec();
    with_checksum.extend_from_slice(checksum);

    bs58::encode(&with_checksum).into_string()
}

fn bs58_check_decode(address: &str) -> Result<Vec<u8>> {
    let decoded = bs58::decode(address)
        .into_vec()
        .context("Invalid base58 address")?;

    if decoded.len() < 4 {
        return Err(anyhow!("Address too short"));
    }

    let data = &decoded[..decoded.len() - 4];
    let checksum = &decoded[decoded.len() - 4..];

    // Verify checksum
    let hash1 = sha256(data);
    let hash2 = sha256(&hash1);
    if &hash2[0..4] != checksum {
        return Err(anyhow!("Invalid checksum"));
    }

    Ok(data.to_vec())
}

fn sha256(data: &[u8]) -> Vec<u8> {
    use sha2::{Digest as Sha2Digest, Sha256};
    let mut hasher = Sha256::new();
    hasher.update(data);
    hasher.finalize().to_vec()
}

fn encode_constructor_params(usdt: &str, owners: &[&str], threshold: u64) -> Result<String> {
    // ABI encode: (address _usdt, address[] _owners, uint256 _threshold)

    // Convert USDT address to hex (without 41 prefix for ABI encoding)
    let usdt_hex = tron_address_to_hex(usdt)?;
    let usdt_addr = &usdt_hex[2..]; // Remove 41 prefix

    // Encode _usdt (address) - pad to 32 bytes
    let usdt_param = format!("{:0>64}", usdt_addr);

    // Encode _threshold
    let threshold_param = format!("{:0>64x}", threshold);

    // Encode owners array
    let owners_len = format!("{:0>64x}", owners.len());
    let mut owners_data = String::new();
    for owner in owners {
        let owner_hex = tron_address_to_hex(owner)?;
        let owner_addr = &owner_hex[2..]; // Remove 41 prefix
        owners_data.push_str(&format!("{:0>64}", owner_addr));
    }

    // ABI encoding for constructor: (address _usdt, address[] _owners, uint256 _threshold)
    // - position 0: address _usdt (32 bytes)
    // - position 1: offset to _owners array (32 bytes) = 96 (0x60)
    // - position 2: uint256 _threshold (32 bytes)
    // - position 3+: array data (length + elements)

    Ok(format!(
        "{}{}{}{}{}",
        usdt_param,                     // address _usdt
        format!("{:0>64x}", 96),        // offset to owners array
        threshold_param,                // uint256 _threshold
        owners_len,                     // array length
        owners_data                     // array elements
    ))
}

fn sign_transaction(tx_id: &str, private_key: &str) -> Result<String> {
    let key_hex = private_key.trim_start_matches("0x");
    let key_bytes = hex::decode(key_hex).context("Invalid private key hex")?;

    let tx_id_bytes = hex::decode(tx_id).context("Invalid tx_id hex")?;

    let secp = Secp256k1::new();
    let secret_key = SecretKey::from_slice(&key_bytes).context("Invalid private key")?;
    let message = Message::from_digest_slice(&tx_id_bytes).context("Invalid message")?;

    let sig = secp.sign_ecdsa_recoverable(&message, &secret_key);
    let (recovery_id, sig_bytes) = sig.serialize_compact();

    // TRON signature format: r (32 bytes) + s (32 bytes) + v (1 byte)
    let mut signature = sig_bytes.to_vec();
    signature.push(recovery_id.to_i32() as u8);

    Ok(hex::encode(signature))
}


fn decode_hex_message(hex_msg: &str) -> String {
    if let Ok(bytes) = hex::decode(hex_msg) {
        if let Ok(s) = String::from_utf8(bytes) {
            return s;
        }
    }
    hex_msg.to_string()
}

fn get_contract_abi() -> &'static str {
    r#"[{"inputs":[{"internalType":"address","name":"_usdt","type":"address"},{"internalType":"address[]","name":"_owners","type":"address[]"},{"internalType":"uint256","name":"_threshold","type":"uint256"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[],"name":"usdt","outputs":[{"internalType":"contract IERC20","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"threshold","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getOwners","outputs":[{"internalType":"address[]","name":"","type":"address[]"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getOwnerCount","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getBalance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getTransactionCount","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_txId","type":"uint256"}],"name":"getTransaction","outputs":[{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"bool","name":"executed","type":"bool"},{"internalType":"uint256","name":"approvalCount","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_txId","type":"uint256"},{"internalType":"address","name":"_owner","type":"address"}],"name":"isApproved","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"isOwner","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_to","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"submitTransaction","outputs":[{"internalType":"uint256","name":"txId","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_txId","type":"uint256"}],"name":"approveTransaction","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_txId","type":"uint256"}],"name":"revokeApproval","outputs":[],"stateMutability":"nonpayable","type":"function"}]"#
}
