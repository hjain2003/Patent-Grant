// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract PatentGrantPortal is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {

    uint256 private _tokenIdCounter;
    string private baseURI;

    constructor() ERC721("PatentToken", "PT") Ownable(msg.sender) {
        _tokenIdCounter = 1;
        baseURI = "https://gateway.pinata.cloud/ipfs/QmTGcHGv59R8HeYmfKgKM2szEZoPn4tkFgNrCj3JE3w76e";
    }

    struct PatentRequest {
        uint256 requestId;
        string disclosure; 
        string briefIdea;
        string[] keywords;
        address requester;
        bool approved;
        uint256 tokenId; // Added to track associated tokenId
    }

    struct Offer {
        address buyer;
        uint256 offerPrice;
    }

    PatentRequest[] public patentRequests;
    PatentRequest[] public approvedPatents;

    mapping(address => PatentRequest[]) public userPatentRequests;
    mapping(uint256 => bool) public existingRequestIds;

    // Mapping to store offers on each tokenId
    mapping(uint256 => Offer) public offers;

    function generateUniqueRequestId() internal returns (uint256) {
        uint256 randomId;
        do {
            randomId = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 900 + 100;
        } while (existingRequestIds[randomId]);

        existingRequestIds[randomId] = true;
        return randomId;
    }

    function removePatentRequest(uint256 index) internal {
        require(index < patentRequests.length, "Invalid index");
        patentRequests[index] = patentRequests[patentRequests.length - 1];
        patentRequests.pop();
    }

    function submitPatentRequest(string memory _disclosure, string memory _briefIdea, string[] memory _keywords) public {
        uint256 newRequestId = generateUniqueRequestId();

        PatentRequest memory newRequest = PatentRequest({
            requestId: newRequestId,
            disclosure: _disclosure,
            briefIdea: _briefIdea,
            keywords: _keywords,
            requester: msg.sender,
            approved: false,
            tokenId: 0 // Initially set to 0 as no token has been minted yet
        });

        patentRequests.push(newRequest);
        userPatentRequests[msg.sender].push(newRequest);
    }

    function viewAllPatentRequests() public view onlyOwner returns (PatentRequest[] memory) {
        return patentRequests;
    }

    function viewApprovedPatents() public view returns (PatentRequest[] memory) {
        return approvedPatents;
    }

    function getPatentRequestByTokenId(uint256 _tokenId) public view onlyOwner returns (PatentRequest memory) {
        for (uint256 i = 0; i < patentRequests.length; i++) {
            if (patentRequests[i].tokenId == _tokenId) {
                return patentRequests[i];
            }
        }
        revert("Patent request not found");
    }

    function findMatchingApprovedPatents(uint256 _tokenId) public view onlyOwner returns (PatentRequest[] memory) {
        PatentRequest memory targetRequest = getPatentRequestByTokenId(_tokenId);
        PatentRequest[] memory tempMatches = new PatentRequest[](approvedPatents.length);
        uint256 matchCount = 0;

        for (uint256 i = 0; i < approvedPatents.length; i++) {
            uint256 matchScore = 0;
            for (uint256 j = 0; j < targetRequest.keywords.length; j++) {
                for (uint256 k = 0; k < approvedPatents[i].keywords.length; k++) {
                    if (keccak256(abi.encodePacked(targetRequest.keywords[j])) == keccak256(abi.encodePacked(approvedPatents[i].keywords[k]))) {
                        matchScore++;
                    }
                }
            }
            if (matchScore > 0) {
                tempMatches[matchCount] = approvedPatents[i];
                matchCount++;
            }
        }

        PatentRequest[] memory matches = new PatentRequest[](matchCount);
        for (uint256 i = 0; i < matchCount; i++) {
            matches[i] = tempMatches[i];
        }

        return matches;
    }

    function acceptPatentRequest(uint256 _requestId) public onlyOwner {
        for (uint256 i = 0; i < patentRequests.length; i++) {
            if (patentRequests[i].requestId == _requestId) {
                require(!patentRequests[i].approved, "Patent already approved");

                // Set patent request as approved
                patentRequests[i].approved = true;

                // Mint token to requester and assign tokenId to the request
                _safeMint(patentRequests[i].requester, _tokenIdCounter);
                _setTokenURI(_tokenIdCounter, baseURI);

                // Update tokenId in the patent request
                patentRequests[i].tokenId = _tokenIdCounter;
                _tokenIdCounter++;

                // Move approved patent to approvedPatents array
                approvedPatents.push(patentRequests[i]);

                // Remove from patentRequests array
                removePatentRequest(i);

                return;
            }
        }
        revert("Patent request not found");
    }

    function submitOffer(uint256 _tokenId) public payable {
        require(ownerOf(_tokenId) != msg.sender, "You already own this patent");
        require(msg.value > 0, "Offer must include Ether");

        offers[_tokenId] = Offer({
            buyer: msg.sender,
            offerPrice: msg.value
        });
    }

    function acceptOffer(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "Only patent owner can accept offers");

        Offer memory offer = offers[_tokenId];
        require(offer.offerPrice > 0, "No valid offer available");

        address previousOwner = ownerOf(_tokenId);
        address buyer = offer.buyer;
        uint256 price = offer.offerPrice;

        // Transfer the patent token (NFT) to the buyer
        _transfer(previousOwner, buyer, _tokenId);

        // Transfer Ether to the previous owner
        payable(previousOwner).transfer(price);

        // Clear the offer
        delete offers[_tokenId];
    }

    function rejectOffer(uint256 _tokenId) public {
        Offer memory offer = offers[_tokenId];
        require(offer.offerPrice > 0, "No valid offer to reject");
        require(ownerOf(_tokenId) == msg.sender || offer.buyer == msg.sender, "Only patent owner or buyer can reject offer");

        address buyer = offer.buyer;
        uint256 offerPrice = offer.offerPrice;

        // Refund the buyer
        payable(buyer).transfer(offerPrice);

        // Clear the offer
        delete offers[_tokenId];
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
