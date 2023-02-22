// SPDX-License-Identifier: MIT
pragma solidity >0.5.0 <=0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error NftMarketplace_priceMustBeAboveZero();
error NftMarketplace_NotApprovedForMarketPlace();
error NftMarketplace_alreadyListed(address nftaddress, uint tokenId);
error NftMarketplace_notOwner();
error NftMarketplace_priceNotMet(address nftAddress, uint tokenId, uint price);
error NftMarketplace_NotListed();
error noProceeds();
error proceedsWithdrawalFailed();

contract NftMarketplace is ReentrancyGuard{
    //1. List Item: Listing Items on the market place for sell
    //2. buyItem: buy the NFT
    //3. Cancel Listing
    //4. Update Listing: update the NFT price
    //5. Withdraw Proceeds: withdraw payments for the bought NFT

    struct Listing {
        uint price;
        address seller;
    }

    //nft address -> tokenId -> listing
   mapping(address => mapping(uint => Listing)) private s_listings;


   //seller address -> amount earned
   mapping(address => uint) private s_proceeds;

   ///////////////////////////////////
   ///    Modifier: Not Listed    ///
   /////////////////////////////////

    modifier notListed(address NftAddress,uint tokenId, address owner) {
        /**
         * @dev we will assign a `listings` variables to any results from `s_listings` mapping
         */
        Listing memory listings = s_listings[NftAddress][tokenId];
        /**
         * @dev we are check if the listed Item price is > than 0, if it is then it as already been listed, then we revert alreadyListed error
         */
        if(listings.price > 0) revert NftMarketplace_alreadyListed(NftAddress, tokenId);
        _;
    }



   ///////////////////////////////////
   ///    Modifier: isListed    ///
   /////////////////////////////////
    modifier isListed(address NftAddress,uint tokenId) {
        Listing memory listings = s_listings[NftAddress][tokenId];
        if(listings.price < 0) revert NftMarketplace_NotListed();
        _;
    }
   ///////////////////////////////////
   ///      Modifier: isOwner     ///
   /////////////////////////////////
   modifier isOwner(address NftAddress, uint tokenId, address spender){
    IERC721 nft = IERC721(NftAddress);
    address owner = nft.ownerOf(tokenId);
    if(spender != owner) revert NftMarketplace_notOwner();
    _;
   }

    event ItemListed( address indexed Seller, address indexed NftAddress, uint indexed tokenId, uint price);
    event itemBought(address indexed buyer, address indexed NFTaddress, uint tokenId, uint price);
    event itemCancelled(address indexed NftAddress, uint indexed tokenId);
    event updatedListing(address indexed NftAddress, uint indexed tokenId, uint indexed newPrice);

    /**
     * @dev The ListItem() is external because we will not let any internal function call the function, we only want external contract to be able to call it.
     * @param NftAddress the NFT address
     * @param tokenId the NFT Id
     * @param price the NFT price
     * @dev We have 2 modifiers... First modifier to check if the NFT has not been listed previously, second modifier to make sure that only the actual owner of the nft can list the NFT or put the Nft up for Sale.
     * @dev we also make that the NFT cannot be listed on the market place is not approved to list it, using the IERC721 interface
     * @dev we create a mappng to map through the NFTaddress to the TokenId to the Listing (price, seller of the listed Nft).
     * @dev we emit an event to log owner/spender of the NFT lising it for sale, the NFT address, the tokenId, and Price of the NFT.
     */

    function listItem(address NftAddress, uint tokenId, uint price) external 
    notListed(NftAddress, tokenId, msg.sender) 
    isOwner(NftAddress,tokenId,msg.sender ) {
        if(price <= 0) revert NftMarketplace_priceMustBeAboveZero();
        /** 
         * @dev since we are listing the item for sell, owners should be able to hold NFTs and give the market place approval for them to sell the NFT. but first we need to make sure the market place has approval to sell our NFTs
         * @dev we will need to get a `getApproved()` will our ERC721 interface IERC721
         */

        /**
         * @dev imported IERC721 and create a 
         */
        IERC721 nft = IERC721(NftAddress);
        if(nft.getApproved(tokenId) != address(this)) revert NftMarketplace_NotApprovedForMarketPlace();

        /**
         * we need a data structure to list this NFTs.
         * Here we will use mapping to mapping the NFT address -> token Id -> listings
         * 
         * Here we created `s_listings` mapping to Listed NFTs with their `prices` and `seller (msg.sender)` who listed the NFTs Item for sell
         */
        s_listings[NftAddress][tokenId] = Listing(price, msg.sender);

        /**
         * We Emit an Event call `Item Listed`
         */
        emit ItemListed(msg.sender, NftAddress, tokenId, price);

        /**
         * @dev We also want to make sure the NFT has not already been listed. we will use a modifier for this 
         * @dev we also want to make sure that only the owner of the NFT can list the NFT or put it up for sale, so we are creating a isOwner Modifier
         */
    }


    function buyItem(address NftAddress, uint tokenId)  
    external 
    payable 
    nonReentrant
    isListed(NftAddress, tokenId){

        Listing memory listedItem = s_listings[NftAddress][tokenId];
        if(msg.value < listedItem.price) revert NftMarketplace_priceNotMet(NftAddress, tokenId, listedItem.price);


        // we dont just send the seller money, we want to seller to withdraw, so we have a withdraw proceeds where all amount earned will be stored there for the seller to withdraw

        //adding amount earned by the seller to a withdraw proceeds, where the seller can withdraw
        s_proceeds[listedItem.seller] += msg.value;

        //once this item is bought we would want to delete the item from been listed
        delete(s_listings[NftAddress][tokenId]);

        //transfer the NFT to the buyer 
        IERC721(NftAddress).safeTransferFrom(listedItem.seller, msg.sender,  tokenId);

        emit itemBought(msg.sender, NftAddress, tokenId, listedItem.price);
    }

    function CancelListing(address NftAddress, uint tokenId) external isListed(NftAddress, tokenId) isOwner(NftAddress, tokenId, msg.sender) {
        delete(s_listings[NftAddress][tokenId]);
        emit itemCancelled(NftAddress, tokenId);
    }

    function updateListing(address NftAddress, uint tokenId, uint newPrice) external
    isOwner(NftAddress, tokenId, msg.sender)
    isListed(NftAddress, tokenId){
        s_listings[NftAddress][tokenId].price = newPrice;
        emit updatedListing(NftAddress, tokenId, newPrice);
    }

    function withdrawProceeds() 
    external 
    nonReentrant{
        uint proceeds = s_proceeds[msg.sender];
        if(proceeds <= 0) revert noProceeds();
        s_proceeds[msg.sender] = 0;
        (bool success,) = payable(msg.sender).call{value: proceeds}("");
        if(!success) revert proceedsWithdrawalFailed();
    }


     //////////////////////////////
    ///    getter functions    ///
   //////////////////////////////

   function getListing(address nftAddress, uint tokenId) external view returns (Listing memory){
    return s_listings[nftAddress][tokenId];
   }

   function getProceeds(address seller) external view returns(uint){
    return s_proceeds[seller];
   }

}