import './style.css'
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { namehash, normalize } from 'viem/ens'

// Constants
const RESOLVER_ADDRESS = '0xF31352EDE0b4673e101D4E77dE119ab7Dd5A7251'

// Create public client
const client = createPublicClient({
  chain: mainnet,
  transport: http()
})

// Query types
const QUERY_TYPES = {
  USER: 'user',
  TOKEN: 'token',
  USER_TOKEN: 'user_token',
  NFT: 'nft'
}

// Current query type
let activeQueryType = QUERY_TYPES.USER

// Example JSON results for different query types
const EXAMPLE_RESULTS = {
  [QUERY_TYPES.USER]: {
    ok: true,
    time: "1739434199",
    block: "21836278",
    erc: 0,
    user: {
      address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      name: "vitalik.eth",
      balance: "964.458627",
      price: "2682.386649"
    }
  },
  [QUERY_TYPES.TOKEN]: {
    ok: true,
    time: "1739434199",
    block: "21836278",
    erc: 20,
    token: {
      contract: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      decimals: 18,
      marketcap: "7911248370.108695",
      name: "Wrapped Ether",
      price: "2682.386649",
      supply: "2949331.847091",
      symbol: "WETH"
    }
  },
  [QUERY_TYPES.USER_TOKEN]: {
    ok: true,
    time: "1739434199",
    block: "21836278",
    erc: 20,
    user: {
      address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      name: "vitalik.eth"
    },
    token: {
      contract: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      balance: "10.458627",
      name: "Wrapped Ether",
      symbol: "WETH"
    }
  },
  [QUERY_TYPES.NFT]: {
    ok: true,
    time: "1739434199",
    block: "21836278",
    erc: 721,
    nft: {
      contract: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
      name: "Bored Ape Yacht Club",
      symbol: "BAYC",
      tokenId: "1234",
      owner: "0xa1b2c3d4e5f6...",
      metadata: {
        name: "BAYC #1234",
        image: "ipfs://..."
      }
    }
  }
}

// Add registered token symbols
const REGISTERED_TOKENS = {
  "dai": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
  "weth": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  "usdc": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  "usdt": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  "bayc": "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
  "ens": "0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72",
  "steth": "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84",
  "cbbtc": "0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf",
  "wbtc": "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
  "link": "0x514910771AF9Ca656af840dff83E8264EcF986CA",
  "aave": "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9",
  "uni": "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
  "shib": "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE",
  "matic": "0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0",
  "comp": "0xc00e94Cb662C3520282E6f5717214004A7f26888",
  "1inch": "0x111111111117dC0aa78b770fA6A738034120C302",
  "grt": "0xc944E90C64B2c07662A292be6244BDf05Cda44a7",
  "bat": "0x0D8775F648430679A709E98d2b0Cb6250d2887EF",
  "ldo": "0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32"
};

// Format JSON simply with indentation
function formatJSON(json) {
  try {
    // Try to find valid JSON in the string if there are any trailing characters
    const jsonMatch = json.match(/(\{.*\})/s)
    const cleanJson = jsonMatch ? jsonMatch[0] : json
    
    // Parse the JSON to ensure it's valid
    const obj = JSON.parse(cleanJson)
    
    // Simply stringify with indentation
    return JSON.stringify(obj, null, 2)
  } catch (e) {
    console.error('Error formatting JSON:', e)
    return json
  }
}

// Clean input (remove .eth if exists)
function cleanInput(input) {
  if (!input) return ''
  return input.toLowerCase().endsWith('.eth') 
    ? input.slice(0, input.length - 4) 
    : input
}

// Create ENS name based on query type
function createEnsName(inputs) {
  try {
    let result = '';
    
    switch (activeQueryType) {
      case QUERY_TYPES.USER:
        result = `${cleanInput(inputs.user)}.jsonapi.eth`
        break
      case QUERY_TYPES.TOKEN:
        result = `${cleanInput(inputs.token)}.jsonapi.eth`
        break
      case QUERY_TYPES.USER_TOKEN:
        result = `${cleanInput(inputs.user)}.${cleanInput(inputs.token)}.jsonapi.eth`
        break
      case QUERY_TYPES.NFT:
        result = `${inputs.tokenId}.${cleanInput(inputs.nftContract)}.jsonapi.eth`
        break
      default:
        return ''
    }
    
    // Normalize the ENS name
    return normalize(result)
  } catch (error) {
    console.error('Error creating ENS name:', error)
    return ''
  }
}

// Convert name to DNS wire format
function toDnsWireFormat(name) {
  try {
    const labels = name.split('.')
    let result = '0x'
    
    for (const label of labels) {
      const encoder = new TextEncoder()
      const bytes = encoder.encode(label)
      
      // Add length byte
      result += bytes.length.toString(16).padStart(2, '0')
      
      // Add label bytes
      for (const byte of bytes) {
        result += byte.toString(16).padStart(2, '0')
      }
    }
    
    // Add null terminator
    result += '00'
    
    return result
  } catch (error) {
    console.error('Error converting to DNS wire format:', error)
    return '0x00'
  }
}

// Convert hex to string
function hexToString(hex) {
  try {
    if (!hex || hex === '0x') return ''
    
    // Remove 0x prefix if exists
    const cleanHex = hex.startsWith('0x') ? hex.slice(2) : hex
    
    // From LibJSON.sol: IPLD_DAG_JSON = hex"e30101800400"
    // The format is: IPLD_DAG_JSON prefix + varint length + actual JSON data
    
    // Skip the IPLD_DAG_JSON prefix (6 bytes = 12 hex chars)
    const IPLD_PREFIX_LENGTH = 12
    
    // Get the first byte of the varint
    const firstVarintByte = parseInt(cleanHex.substring(IPLD_PREFIX_LENGTH, IPLD_PREFIX_LENGTH + 2), 16)
    
    // Check if varint is 1 or 2 bytes based on MSB
    // If first byte >= 128 (0x80), it's a 2-byte varint, otherwise it's 1 byte
    const varintLength = firstVarintByte >= 128 ? 4 : 2 // In hex chars (2 or 4)
    
    // Start position for JSON data is after prefix + varint
    const jsonStartPos = IPLD_PREFIX_LENGTH + varintLength
    
    // Extract just the JSON part (start from { which is 0x7b in hex)
    let actualJsonStart = jsonStartPos
    while (actualJsonStart < cleanHex.length) {
      if (cleanHex.substring(actualJsonStart, actualJsonStart + 2) === '7b') {
        break
      }
      actualJsonStart += 2
    }
    
    // Find the end of JSON - look for the last '}'
    let jsonEndPos = cleanHex.lastIndexOf('7d')
    if (jsonEndPos !== -1) {
      jsonEndPos += 2 // Include the '}'
    } else {
      jsonEndPos = cleanHex.length
    }
    
    const jsonHex = cleanHex.substring(actualJsonStart, jsonEndPos)
    
    // Convert the JSON hex to string
    let result = ''
    for (let i = 0; i < jsonHex.length; i += 2) {
      const charCode = parseInt(jsonHex.substr(i, 2), 16)
      result += String.fromCharCode(charCode)
    }
    
    return result
  } catch (error) {
    console.error('Error converting hex to string:', error)
    return ''
  }
}

// Query the ENS resolver
async function queryResolver(ensName) {
  try {
    // Normalize name for consistency
    const normalizedName = normalize(ensName)
    console.log('Normalized ENS name:', normalizedName)
    
    // Calculate the namehash
    const hash = namehash(normalizedName)
    console.log('ENS namehash:', hash)
    
    // Convert name to DNS wire format
    const dnsWireData = toDnsWireFormat(normalizedName)
    console.log('DNS Wire Format:', dnsWireData)
    
    // Create contenthash request with the correct namehash
    const contenthashSelector = '0xbc1c58d1'
    const contenthashRequest = contenthashSelector + hash.slice(2) // Remove 0x from namehash
    
    // Manually encode the resolve call
    // Function selector for resolve(bytes,bytes) is 0x9061b923
    const selector = '0x9061b923'
    
    // Offsets (position of dynamic data)
    // First offset is always 0x40 (64 bytes)
    const offset1 = '0000000000000000000000000000000000000000000000000000000000000040'
    
    // Calculate length of first parameter in bytes
    const nameBytes = (dnsWireData.length - 2) / 2 // Remove 0x, divide by 2 for bytes
    
    // Second offset is 64 + nameLength + 32 (32 bytes for length word)
    const offset2 = (64 + 32 + Math.ceil(nameBytes / 32) * 32).toString(16).padStart(64, '0')
    
    // Encode lengths
    const nameLength = nameBytes.toString(16).padStart(64, '0')
    
    // Remove 0x prefix
    const nameData = dnsWireData.slice(2)
    
    // Padding to 32-byte boundary
    const namePadding = '0'.repeat((32 - (nameBytes % 32)) % 32 * 2)
    
    // Request data (contenthash request)
    const requestLength = ((contenthashRequest.length - 2) / 2).toString(16).padStart(64, '0')
    const requestData = contenthashRequest.slice(2)
    
    // Build calldata
    const calldata = selector + 
                    offset1 + 
                    offset2 + 
                    nameLength +
                    nameData + 
                    namePadding + 
                    requestLength + 
                    requestData
    
    console.log('Calldata:', calldata)
    
    // Call the resolver
    const result = await client.call({
      to: RESOLVER_ADDRESS,
      data: calldata
    })
    
    console.log('Raw result:', result)
    
    // If empty result
    if (!result || !result.data || result.data === '0x') {
      return JSON.stringify({ error: 'No data returned from resolver' })
    }
    
    // Get the data from the result object
    const resultData = result.data
    
    // Decode the result
    // First 32 bytes (64 hex chars after 0x) is the offset
    const resultOffset = parseInt(resultData.slice(2, 66), 16)
    
    // At the offset, next 32 bytes is the length
    const resultLengthHex = resultData.slice(2 + resultOffset * 2, 2 + resultOffset * 2 + 64)
    const resultLength = parseInt(resultLengthHex, 16)
    
    // Extract the actual bytes
    const contentBytes = resultData.slice(2 + resultOffset * 2 + 64, 2 + resultOffset * 2 + 64 + resultLength * 2)
    
    // Convert to string
    const jsonString = hexToString(contentBytes)
    
    return formatJSON(jsonString)
  } catch (error) {
    console.error('Error querying resolver:', error)
    return JSON.stringify({ error: error.message })
  }
}

// Handle form submission
async function handleSubmit(event) {
  event.preventDefault()
  
  const formData = new FormData(event.target)
  const inputs = Object.fromEntries(formData.entries())
  
  // Validate inputs based on current activeQueryType
  let validInput = true
  let errorMessage = ''
  
  switch (activeQueryType) {
    case QUERY_TYPES.USER:
      validInput = !!inputs.user
      errorMessage = 'Please enter a user address or ENS name'
      break
    case QUERY_TYPES.TOKEN:
      validInput = !!inputs.token
      errorMessage = 'Please enter a token symbol or address'
      break
    case QUERY_TYPES.USER_TOKEN:
      validInput = !!inputs.user && !!inputs.token
      errorMessage = 'Please enter both user and token information'
      break
    case QUERY_TYPES.NFT:
      validInput = !!inputs.tokenId && !!inputs.nftContract
      errorMessage = 'Please enter both token ID and NFT contract information'
      break
  }
  
  if (!validInput) {
    document.getElementById('results').textContent = errorMessage
    return
  }
  
  // Create ENS name
  const ensName = createEnsName(inputs)
  const resolvedName = document.getElementById('resolved-name')
  const ensLink = document.getElementById('ens-link')
  
  if (resolvedName) {
    resolvedName.textContent = ensName
  }
  if (ensLink) {
    ensLink.href = `https://app.ens.domains/${ensName}`
  }
  
  // Show loading state
  document.getElementById('results').textContent = 'Loading...'
  
  try {
    // Query the resolver
    const result = await queryResolver(ensName)
    
    // Use textContent for proper preformatted display
    document.getElementById('results').textContent = result
  } catch (error) {
    console.error('Error:', error)
    document.getElementById('results').textContent = `Error: ${error.message}`
  }
}

// Set active query type
function setQueryType(type) {
  // Update active query type
  activeQueryType = type;

  // Update active query type button
  document.querySelectorAll('.query-type').forEach(el => {
    el.classList.toggle('active', el.dataset.type === type);
  });

  // Update visible query info
  document.querySelectorAll('.query-info-item').forEach(el => {
    el.classList.toggle('active', el.id === `info-${type}`);
  });

  // Update form fields visibility
  const userField = document.getElementById('user-field');
  const tokenField = document.getElementById('token-field');
  const tokenIdField = document.getElementById('token-id-field');
  const nftContractField = document.getElementById('nft-contract-field');

  userField.style.display = ['user', 'user_token'].includes(type) ? 'block' : 'none';
  tokenField.style.display = ['token', 'user_token'].includes(type) ? 'block' : 'none';
  tokenIdField.style.display = type === 'nft' ? 'block' : 'none';
  nftContractField.style.display = type === 'nft' ? 'block' : 'none';

  // Reset form and example results
  const form = document.getElementById('query-form');
  if (form) {
    form.reset();
  }
  updateExampleResult(type);
}

// Update the example result based on query type
function updateExampleResult(type) {
  // Reset the results
  const results = document.getElementById('results')
  const resolvedName = document.getElementById('resolved-name')
  const ensLink = document.getElementById('ens-link')
  
  if (results) {
    results.textContent = JSON.stringify(EXAMPLE_RESULTS[type], null, 2)
  }
  
  // Update example query name
  const exampleNames = {
    [QUERY_TYPES.USER]: 'vitalik.jsonapi.eth',
    [QUERY_TYPES.TOKEN]: 'weth.jsonapi.eth',
    [QUERY_TYPES.USER_TOKEN]: 'vitalik.weth.jsonapi.eth',
    [QUERY_TYPES.NFT]: '1234.bayc.jsonapi.eth'
  }
  
  if (resolvedName) {
    const name = exampleNames[type]
    resolvedName.textContent = name
    if (ensLink) {
      ensLink.href = `https://app.ens.domains/${name}`
    }
  }
}

// Initialize datalists with token options
function initializeTokenLists() {
  // Initialize token list
  const tokenList = document.getElementById('token-list')
  if (tokenList) {
    tokenList.innerHTML = Object.entries(REGISTERED_TOKENS).map(([symbol, address]) => 
      `<option value="${symbol}">${symbol.toUpperCase()} - ${address}</option>`
    ).join('')
  }
  
  // Initialize NFT list
  const nftList = document.getElementById('nft-list')
  if (nftList) {
    nftList.innerHTML = `<option value="bayc">BAYC - ${REGISTERED_TOKENS['bayc']}</option>`
  }
}

// Add event listeners
document.querySelectorAll('.query-type').forEach(el => {
  el.addEventListener('click', () => setQueryType(el.dataset.type))
})

// Handle token input changes
document.getElementById('token')?.addEventListener('input', (e) => {
  const value = e.target.value.toLowerCase();
  if (REGISTERED_TOKENS[value]) {
    e.target.setAttribute('data-address', REGISTERED_TOKENS[value]);
  } else {
    e.target.removeAttribute('data-address');
  }
});

document.getElementById('nftContract')?.addEventListener('input', (e) => {
  const value = e.target.value.toLowerCase();
  if (REGISTERED_TOKENS[value]) {
    e.target.setAttribute('data-address', REGISTERED_TOKENS[value]);
  } else {
    e.target.removeAttribute('data-address');
  }
});

document.getElementById('query-form').addEventListener('submit', handleSubmit)

// Initialize the app
function initializeApp() {
  initializeTokenLists()
  setQueryType(QUERY_TYPES.USER)
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', initializeApp)
