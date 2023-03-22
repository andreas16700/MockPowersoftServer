import Vapor
import PowersoftKit

extension PSItem: Content{}
extension PSListStockStoresItem: Content {}
extension HTTPStatus: Error, Content{}
extension Wrapper: Content {}
extension PSListModel: Content{}
extension ModelAndItsStocks: Content{}
//extension String: Content {}
struct Wrapper<T: Codable>: Codable{
	let content: T
}
func routes(_ app: Application) throws {
	//MARK: General
	app.get { req async in
		"mock ps server"
	}
	app.get("reset","all"){req async throws -> HTTPStatus in
		await store.resetAll()
		return .ok
	}
	app.get("generate",":modelsCount",":xSeed",":ySeed"){ req async throws -> String in
		guard let modelsCount = req.parameters.get("modelsCount", as: Int.self),
			  let xSeed = req.parameters.get("xSeed", as: UInt64.self),
			  let ySeed = req.parameters.get("ySeed", as: UInt64.self) else{
			throw HTTPStatus.badRequest
		}
		var gen: RandomNumberGenerator = Xorshift128Plus(xSeed: xSeed, ySeed: ySeed)
		let models: [String: [PSItem]] = Array(0..<modelsCount).reduce(into: [String: [PSItem]]()){dict, i in
			let modelItemCount = Int.random(in: 1...20, using: &gen)
			let modelCode = "model\(i)"
			let items = PSItem.generateModel(modelCode: modelCode, itemsCount: modelItemCount, usingPRNG: &gen)
			guard dict[modelCode] == nil else {
				print("tf")
				fatalError()
			}
			dict[modelCode]=items
		}
		await store.addNewModels(models: models, usingPRNG: &gen)
		return "Generated \(modelsCount) models"
	}
	app.get("generate",":modelsCount"){ req async throws -> String in
		var gen: RandomNumberGenerator = Xorshift128Plus(xSeed: 3199077918806463242, ySeed: 11403738689752549865)
		let modelsCountStr = req.parameters.get("modelsCount")!
		guard let modelsCount = Int(modelsCountStr) else {throw HTTPStatus.badRequest}
		let models: [String: [PSItem]] = Array(0..<modelsCount).reduce(into: [String: [PSItem]]()){dict, i in
			let modelItemCount = Int.random(in: 1...20, using: &gen)
			let modelCode = "model\(i)"
			let items = PSItem.generateModel(modelCode: modelCode, itemsCount: modelItemCount, usingPRNG: &gen)
			guard dict[modelCode] == nil else {
				print("tf")
				fatalError()
			}
			dict[modelCode]=items
		}
		await store.addNewModels(models: models, usingPRNG: &gen)
		return "Generated \(modelsCount) models"
	}
	//MARK: Items
	//only eCommerce items are relevant in this context
	//thus we ignore the type
	//	func getItem(itemCode: String)async->PSItem?
	app.get("item", ":itemCode"){ req async throws -> PSItem in
		let itemCode = req.parameters.get("itemCode")!
		guard let item = await store.getItem(itemCode: itemCode) else {throw HTTPStatus.badRequest}
		return item
	}
	//	func getAllItemsCount(type: eCommerceType)async ->Int?
	app.get("items","count"){ req async throws -> Wrapper<Int> in
		let count = await store.allItems.count
		return Wrapper(content: count)
	}
	//	func getItemsPage(page: Int, type: eCommerceType)async ->[PSItem]?
	app.get("items","page",":pageNum"){req async throws -> [PSItem] in
		let pageNum = req.parameters.get("pageNum", as: Int.self)!
//		guard let pageNum = Int(pageNumStr) else {throw HTTPStatus.badRequest}
		guard let page = await store.getItemsPage(page: pageNum) else{
			throw HTTPStatus.notFound
		}
		return page
	}
	app.get("items","all"){req async throws -> [PSItem] in
		return await store.allItems
	}
	//MARK: Stocks
	//	func getStock(for itemCode: String)async->PSListStockStoresItem?
	app.get("stock", ":itemCode"){ req async throws -> PSListStockStoresItem in
		let itemCode = req.parameters.get("itemCode")!
		guard let item = await store.getStock(for: itemCode) else {throw HTTPStatus.badRequest}
		return item
	}
	//	func getAllStockCount(type: eCommerceType)async->Int?
	app.get("stocks","count"){ req async throws -> Wrapper<Int> in
		guard let count = await store.getAllStockCount() else {throw HTTPStatus.internalServerError}
		return Wrapper(content: count)
	}
	//	func getStocksPage(page: Int, type: eCommerceType)async -> [PSListStockStoresItem]?
	app.get("stocks","page",":pageNum"){req async throws -> [PSListStockStoresItem] in
		let pageNumStr = req.parameters.get("pageNum")!
		guard let pageNum = Int(pageNumStr) else {throw HTTPStatus.badRequest}
		guard let page = await store.getStocksPage(page: pageNum) else{
			throw HTTPStatus.notFound
		}
		return page
	}
	//MARK: Models
	app.get("firstModelItemsAndStocks",":count"){ req async throws -> [ModelAndItsStocks] in
		guard let count = req.parameters.get("count", as: Int.self) else {throw HTTPStatus.badRequest}
		return await store.getFirstModelsAndTheirStocks(count: count)
	}
	//	func getModel(modelCode: String)async->[PSItem]?
	app.get("modelItem",":modelCode"){ req async throws -> [PSItem] in
		let modelCode = req.parameters.get("modelCode")!
		guard let model = await store.getModel(modelCode: modelCode) else {throw HTTPStatus.badRequest}
		return model
	}
	app.get("model",":modelCode"){ req async throws -> PSListModel in
		let modelCode = req.parameters.get("modelCode")!
		guard let model = await store.getModelMetadata(modelCode: modelCode) else {throw HTTPStatus.badRequest}
		return model
	}
	//	func getAllModelsCount(type: eCommerceType)async ->Int?
	app.get("models","count"){ req async throws -> Wrapper<Int> in
		let count = await store.allModelsMetadata.count
		return Wrapper(content: count)
	}
	//	func getModelsPage(page: Int, type: eCommerceType)async ->[PSListModel]?
	app.get("models","page",":pageNum"){req async throws -> [PSListModel] in
		let pageNumStr = req.parameters.get("pageNum")!
		guard let pageNum = Int(pageNumStr) else {throw HTTPStatus.badRequest}
		guard let page = await store.getModelsPage(page: pageNum) else{
			throw HTTPStatus.notFound
		}
		return page
	}
	//
	app.get("allModelItems"){req async throws -> [String: [PSItem]] in
		let m = await store.modelItemsByModelCode
		return m
	}
}
var store = MockPowersoftStore(models: .init(), modelsMetadata: .init(), stockByItemCode: .init())
func decodeToType<T: Decodable>(_ b: ByteBuffer?, to type: T.Type)throws ->T?{
	guard let buf = b else {try reportError(ServerErrors.emptyBody); return nil}
	return try decoder.decode(T.self, from: buf)
}
func reportError(_ e: Error? = nil, _ msg: String? = nil)throws{
	if let msg{
		print(msg)
	}
	if let e{
		print("\(e)")
	}
	throw e ?? ServerErrors.other(msg ?? "unknown error occured")
}
enum ServerErrors:Error{
	case emptyBody
	case nonUTF8Body
	case nonDecodableBody
	case other(String)
}

let encoder = JSONEncoder()
let decoder = JSONDecoder()
extension MockPowersoftStore{
	var pageSize: Int {100}
	
}
extension Collection{
	func asyncMap<T>(_ transform: (Element)async throws->T)async rethrows->[T]{
		var r: [T] = .init()
		for item in self{
			let e = try await transform(item)
			r.append(e)
		}
		return r
	}
}
