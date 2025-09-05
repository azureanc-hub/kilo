// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title GlobalStorage
 * @dev Optimized decentralized file storage contract
 * @author Lies_Of_Code
 */
contract GlobalStorage {
    
    struct FileInfo {
        string fileName;
        string fileType;
        string ipfsHash;
        uint256 fileSize;
        uint256 uploadTime;
        address owner;
        bool isPublic;
        string description;
        string[] tags;
    }

    struct FileAccess {
        uint256 fileId;
        address user;
        bool hasAccess;
    }

    struct Access {
        address user;
        bool access;
    }

    FileInfo[] public globalFiles;
    mapping(address => uint256[]) private userFileIds;
    mapping(address => mapping(address => bool)) private ownership;
    mapping(address => Access[]) private accessList;
    mapping(uint256 => mapping(address => bool)) private fileAccess;
    mapping(address => FileAccess[]) private fileAccessList;

    event FileUploaded(address indexed user, uint256 indexed fileId, string fileName, string ipfsHash);
    event AccessGranted(address indexed owner, address indexed user);
    event AccessRevoked(address indexed owner, address indexed user);
    event FileDeleted(address indexed user, uint256 indexed fileId);
    event FileAccessGranted(address indexed owner, address indexed user, uint256 indexed fileId);
    event FileAccessRevoked(address indexed owner, address indexed user, uint256 indexed fileId);

    function addFile(
        string memory _fileName,
        string memory _fileType,
        string memory _ipfsHash,
        uint256 _fileSize,
        bool _isPublic,
        string memory _description,
        string[] memory _tags
    ) external {
        require(bytes(_fileName).length > 0, "File name cannot be empty");
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");
        require(_fileSize > 0, "File size must be greater than 0");

        FileInfo memory newFile = FileInfo({
            fileName: _fileName,
            fileType: _fileType,
            ipfsHash: _ipfsHash,
            fileSize: _fileSize,
            uploadTime: block.timestamp,
            owner: msg.sender,
            isPublic: _isPublic,
            description: _description,
            tags: _tags
        });

        globalFiles.push(newFile);
        uint256 fileId = globalFiles.length - 1;
        userFileIds[msg.sender].push(fileId);

        emit FileUploaded(msg.sender, fileId, _fileName, _ipfsHash);
    }

    function getMyFiles() external view returns (FileInfo[] memory, uint256[] memory) {
        require(userFileIds[msg.sender].length > 0, "You have no files stored");
        
        uint256[] memory myFileIds = userFileIds[msg.sender];
        FileInfo[] memory myFiles = new FileInfo[](myFileIds.length);
        uint256[] memory fileIds = new uint256[](myFileIds.length);
        
        for (uint256 i = 0; i < myFileIds.length; i++) {
            if (myFileIds[i] < globalFiles.length && globalFiles[myFileIds[i]].owner != address(0)) {
                myFiles[i] = globalFiles[myFileIds[i]];
                fileIds[i] = myFileIds[i];
            }
        }
        
        return (myFiles, fileIds);
    }

    function getPublicFiles() external view returns (FileInfo[] memory, uint256[] memory) {
        uint256 publicCount = 0;
        for (uint256 i = 0; i < globalFiles.length; i++) {
            if (globalFiles[i].isPublic && globalFiles[i].owner != address(0)) {
                publicCount++;
            }
        }

        FileInfo[] memory publicFiles = new FileInfo[](publicCount);
        uint256[] memory fileIds = new uint256[](publicCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < globalFiles.length; i++) {
            if (globalFiles[i].isPublic && globalFiles[i].owner != address(0)) {
                publicFiles[currentIndex] = globalFiles[i];
                fileIds[currentIndex] = i;
                currentIndex++;
            }
        }
        
        return (publicFiles, fileIds);
    }

    function getUserFiles(address _user) external view returns (FileInfo[] memory, uint256[] memory) {
        require(_user != address(0), "Invalid user address");
        
        bool hasGeneralAccess = (_user == msg.sender) || ownership[_user][msg.sender];
        uint256[] memory userFiles = userFileIds[_user];
        
        uint256 accessibleCount = 0;
        for (uint256 i = 0; i < userFiles.length; i++) {
            uint256 fileId = userFiles[i];
            if (fileId < globalFiles.length && globalFiles[fileId].owner != address(0)) {
                if (globalFiles[fileId].isPublic || hasGeneralAccess || fileAccess[fileId][msg.sender]) {
                    accessibleCount++;
                }
            }
        }
        
        require(accessibleCount > 0, "Access denied: No accessible files found");
        
        FileInfo[] memory files = new FileInfo[](accessibleCount);
        uint256[] memory fileIds = new uint256[](accessibleCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < userFiles.length; i++) {
            uint256 fileId = userFiles[i];
            if (fileId < globalFiles.length && globalFiles[fileId].owner != address(0)) {
                if (globalFiles[fileId].isPublic || hasGeneralAccess || fileAccess[fileId][msg.sender]) {
                    files[currentIndex] = globalFiles[fileId];
                    fileIds[currentIndex] = fileId;
                    currentIndex++;
                }
            }
        }
        
        return (files, fileIds);
    }

    function grantFileAccess(uint256 _fileId, address _user) external {
        require(_fileId < globalFiles.length, "File does not exist");
        require(globalFiles[_fileId].owner == msg.sender, "Only owner can grant access");
        require(_user != msg.sender, "Cannot grant access to yourself");
        require(_user != address(0), "Invalid user address");
        require(globalFiles[_fileId].owner != address(0), "File has been deleted");

        fileAccess[_fileId][_user] = true;
        
        bool accessExists = false;
        for (uint256 i = 0; i < fileAccessList[msg.sender].length; i++) {
            if (fileAccessList[msg.sender][i].fileId == _fileId && 
                fileAccessList[msg.sender][i].user == _user) {
                fileAccessList[msg.sender][i].hasAccess = true;
                accessExists = true;
                break;
            }
        }
        
        if (!accessExists) {
            fileAccessList[msg.sender].push(FileAccess(_fileId, _user, true));
        }

        emit FileAccessGranted(msg.sender, _user, _fileId);
    }

    function revokeFileAccess(uint256 _fileId, address _user) external {
        require(_fileId < globalFiles.length, "File does not exist");
        require(globalFiles[_fileId].owner == msg.sender, "Only owner can revoke access");
        require(fileAccess[_fileId][_user], "User doesn't have access to this file");

        fileAccess[_fileId][_user] = false;
        
        for (uint256 i = 0; i < fileAccessList[msg.sender].length; i++) {
            if (fileAccessList[msg.sender][i].fileId == _fileId && 
                fileAccessList[msg.sender][i].user == _user) {
                fileAccessList[msg.sender][i].hasAccess = false;
                break;
            }
        }

        emit FileAccessRevoked(msg.sender, _user, _fileId);
    }

    function getFileAccessList() external view returns (FileAccess[] memory) {
        return fileAccessList[msg.sender];
    }

    function allow(address user) external {
        require(user != msg.sender, "Cannot grant access to yourself");
        require(user != address(0), "Invalid user address");

        ownership[msg.sender][user] = true;
        
        bool userExistsInList = false;
        for (uint256 i = 0; i < accessList[msg.sender].length; i++) {
            if (accessList[msg.sender][i].user == user) {
                accessList[msg.sender][i].access = true;
                userExistsInList = true;
                break;
            }
        }
        
        if (!userExistsInList) {
            accessList[msg.sender].push(Access(user, true));
        }

        emit AccessGranted(msg.sender, user);
    }

    function disallow(address user) external {
        require(ownership[msg.sender][user], "User doesn't have access");

        ownership[msg.sender][user] = false;
        
        for (uint256 i = 0; i < accessList[msg.sender].length; i++) {
            if (accessList[msg.sender][i].user == user) {
                accessList[msg.sender][i].access = false;
                break;
            }
        }

        emit AccessRevoked(msg.sender, user);
    }

    function shareAccess() external view returns (Access[] memory) {
        return accessList[msg.sender];
    }

    function deleteFile(uint256 _fileId) external {
        require(_fileId < globalFiles.length, "File does not exist");
        require(globalFiles[_fileId].owner == msg.sender, "Only owner can delete file");

        uint256[] storage userFiles = userFileIds[msg.sender];
        for (uint256 i = 0; i < userFiles.length; i++) {
            if (userFiles[i] == _fileId) {
                userFiles[i] = userFiles[userFiles.length - 1];
                userFiles.pop();
                break;
            }
        }

        globalFiles[_fileId].owner = address(0);
        
        emit FileDeleted(msg.sender, _fileId);
    }

    function hasFileAccess(uint256 _fileId, address _user) external view returns (bool) {
        require(_fileId < globalFiles.length, "File does not exist");
        
        FileInfo memory file = globalFiles[_fileId];
        
        if (file.owner == _user || file.isPublic || ownership[file.owner][_user]) {
            return true;
        }
        
        return fileAccess[_fileId][_user];
    }
}