/*
*     Copyright 2016 IBM Corp.
*     Licensed under the Apache License, Version 2.0 (the "License");
*     you may not use this file except in compliance with the License.
*     You may obtain a copy of the License at
*     http://www.apache.org/licenses/LICENSE-2.0
*     Unless required by applicable law or agreed to in writing, software
*     distributed under the License is distributed on an "AS IS" BASIS,
*     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*     See the License for the specific language governing permissions and
*     limitations under the License.
*/

import Foundation
import SimpleLogger
import SimpleHttpClient

/// ObjectStorageContainer instance represents a single container on IBM Object Store service
public class ObjectStorageContainer{

	/// Container name
	public let name:String

	/// Container resource
	public let resource:HttpResource

	internal let objectStore:ObjectStorage
	private let logger:Logger

	internal init(name:String, resource: HttpResource, objectStore:ObjectStorage){
		self.logger = Logger(forName:"ObjectStoreContainer [\(name)]")
		self.name = name
		self.resource = resource
		self.objectStore = objectStore
	}

	/**
	Create a new object or update an existing one. In case object with a same name already exists it will be replaced with the new content.

	- Parameter name: The name of the object to be stored
	- Parameter data: The object content
	- Parameter completionHandler: Closure to be executed once object is created
	*/
	public func storeObject(name:String, data:NSData, completionHandler: (error: ObjectStorageError?, object: ObjectStorageObject?)->Void){
		logger.info("Storing object [\(name)]")
		let headers = Utils.createHeaderDictionary(authToken: objectStore.authTokenManager?.authToken)
		let resource = self.resource.resourceByAddingPathComponent(pathComponent: Utils.urlPathEncode(text: "/" + name))
		
		HttpClient.put(resource: resource, headers: headers, data: data) { error, status, headers, responseData in
			if let error = error{
				completionHandler(error: ObjectStorageError.from(httpError: error), object: nil)
			} else {
				self.logger.info("Stored object [\(name)]")
				let object = ObjectStorageObject(name: name, resource: resource, container: self, data: data)
				completionHandler(error: nil, object: object)
			}
		}

	}

	
	/**
	Retrieve an existing object

	- Parameter name: The name of the object to be retrieved
	- Parameter completionHandler: Closure to be executed once object is retrieved
	*/
	public func retrieveObject(name:String, completionHandler: (error: ObjectStorageError?, object: ObjectStorageObject?)->Void){
		logger.info("Retrieving object [\(name)]")
		let headers = Utils.createHeaderDictionary(authToken: objectStore.authTokenManager?.authToken)
		let resource = self.resource.resourceByAddingPathComponent(pathComponent: Utils.urlPathEncode(text: "/" + name))
		
		HttpClient.get(resource: resource, headers: headers) { error, status, headers, data in
			if let error = error{
				completionHandler(error: ObjectStorageError.from(httpError: error), object: nil)
			} else {
				self.logger.info("Retrieved object [\(name)]")
				let object = ObjectStorageObject(name: name, resource: resource, container: self, data: data)
				completionHandler(error: nil, object: object)
			}
		}
	}


	/**
	Retrieve a list of existing objects

	- Parameter completionHandler: Closure to be executed once object list is retrieved
	*/
	public func retrieveObjectsList(completionHandler: (error: ObjectStorageError?, objects: [ObjectStorageObject]?)->Void){
		logger.info("Retrieving objects list")
		let headers = Utils.createHeaderDictionary(authToken: objectStore.authTokenManager?.authToken)
		HttpClient.get(resource: resource, headers: headers) { error, status, headers, data in
			if let error = error{
				completionHandler(error: ObjectStorageError.from(httpError: error), objects: nil)
			}else {
				self.logger.info("Retrieved objects list")
				var objectsList = [ObjectStorageObject]()
				let responseBodyString = String(data: data!, encoding: NSUTF8StringEncoding)!
				
				let objectNames = responseBodyString.components(separatedBy: "\n")
				
				for objectName:String in objectNames{
					if objectName.characters.count == 0 {
						continue
					}
					let objectResource = self.resource.resourceByAddingPathComponent(pathComponent: Utils.urlPathEncode(text: "/" + objectName))
					let object = ObjectStorageObject(name: objectName, resource: objectResource, container: self)
					objectsList.append(object)
				}
				completionHandler(error: nil, objects: objectsList)
			}

		}

	}

	/**
	Delete an existing object

	- Parameter name: The name of the object to be deleted
	- Parameter completionHandler: Closure to be executed once object is deleted
	*/
	public func deleteObject(name: String, completionHandler: (error:ObjectStorageError?) -> Void){
		logger.info("Deleting object [\(name)]")
		let headers = Utils.createHeaderDictionary(authToken: objectStore.authTokenManager?.authToken)
		let resource = self.resource.resourceByAddingPathComponent(pathComponent: Utils.urlPathEncode(text: "/" + name))
		
		HttpClient.delete(resource: resource, headers: headers) { error, status, headers, data in
			if let error = error {
				completionHandler(error: ObjectStorageError.from(httpError: error))
			} else {
				self.logger.info("Deleted object [\(name)]")
				completionHandler(error: nil)
			}
		}
	}

	/**
	Delete the container

	- Parameter completionHandler: Closure to be executed once container is deleted
	*/
	public func delete(completionHandler:(error: ObjectStorageError?)->Void){
		self.objectStore.deleteContainer(name: self.name, completionHandler: completionHandler)
	}

	/**
	Update container metadata

	- Parameter metadata: a dictionary of metadata items, e.g. ["X-Container-Meta-Subject":"AmericanHistory"]. It is possible to supply multiple metadata items within same invocation. To delete a particular metadata item set it's value to an empty string, e.g. ["X-Container-Meta-Subject":""]. See Object Storage API v1 for more information about possible metadata items - http://developer.openstack.org/api-ref-objectstorage-v1.html
	- Parameter completionHandler: Closure to be executed once metadata is updated.
	*/
	public func updateMetadata(metadata:Dictionary<String, String>, completionHandler: (error: ObjectStorageError?)->Void){
		logger.info("Updating metadata :: \(metadata)")
		
		let headers = Utils.createHeaderDictionary(authToken: objectStore.authTokenManager?.authToken, additionalHeaders: metadata)
		
		HttpClient.post(resource: resource, headers: headers) { error, status, headers, data in
			if let error = error {
				completionHandler(error:ObjectStorageError.from(httpError: error))
			} else {
				self.logger.info("Metadata updated :: \(metadata)")
				completionHandler(error:nil)
			}
		}

	}

	/**
	Retrieve container metadata. The metadata will be returned to a completionHandler as a Dictionary<String, String> instance with set of keys and values

	- Parameter completionHandler: Closure to be executed once metadata is retrieved.
	*/
	public func retrieveMetadata(completionHandler: (error: ObjectStorageError?, metadata: [String:String]?) -> Void) {
		logger.info("Retrieving metadata")
		
		let headers = Utils.createHeaderDictionary(authToken: objectStore.authTokenManager?.authToken)
		HttpClient.head(resource: resource, headers: headers) { error, status, headers, data in
			if let error = error {
				completionHandler(error: ObjectStorageError.from(httpError: error), metadata: nil)
			} else {
				self.logger.info("Metadata retrieved :: \(headers)")
				completionHandler(error: nil, metadata: headers);
			}
		}
	}
}

