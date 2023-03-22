import PowersoftClient
import PowersoftKit

public actor MockPowersoftStore{
	public init(
		models: [String: [PSItem]],
		pageItemCapacity: Int = 10000,
		modelsMetadata: [String: PSListModel],
		stockByItemCode: [String: PSListStockStoresItem]
	){
		self.modelItemsByModelCode=models
		self.pageCapacity=pageItemCapacity
		self.modelsMetadataByModelCode = modelsMetadata
		self.stockByItemCode=stockByItemCode
	}
	private let pageCapacity: Int
	private var modelsMetadataByModelCode: [String: PSListModel]
	private(set) var modelItemsByModelCode: [String: [PSItem]]
	private var stockByItemCode: [String: PSListStockStoresItem]
	public func getItem(itemCode: String) async -> PSItem? {
		return modelItemsByModelCode.values.firstResult(where: {$0.first(where: {item in
			item.itemCode365==itemCode
		})})
	}
	var allItems: [PSItem]{
		return modelItemsByModelCode.allValuesAsOneCollection()
	}
	var allModelsMetadata: [PSListModel]{
		return Array(modelsMetadataByModelCode.values)
	}
	var allStocks: [PSListStockStoresItem]{
		return Array(stockByItemCode.values)
	}
	public func resetAll(){
		self.modelItemsByModelCode = .init()
		self.modelsMetadataByModelCode = .init()
		self.stockByItemCode = .init()
	}
	public func addNewModel(modelCode: String, model: [PSItem], usingPRNG prng: inout RandomNumberGenerator){
		guard let anItem = model.randomElement() else {return}
		self.modelItemsByModelCode[modelCode] = model
		
		let modelMetadata = anItem.generateModelMetadata()
		self.modelsMetadataByModelCode[modelCode] = modelMetadata
		
		for item in model{
			let stock = item.generateStock(usingPRNG: &prng)
			self.stockByItemCode[item.itemCode365] = stock
		}
	}
	public func addNewModels(models: [String: [PSItem]], usingPRNG prng: inout RandomNumberGenerator){
		for (modelCode, model) in models{
			addNewModel(modelCode: modelCode, model: model, usingPRNG: &prng)
		}
	}
	public func getAllItemsCount() async -> Int? {
		return allItems.count
	}
	
	public func getItemsPage(page: Int) -> [PSItem]? {
		return allItems.getPaginatedSlice(pageNumber: page, pageSize: pageCapacity)
	}
	
	public func getAllItems() async -> [PSItem]? {
		return allItems
	}
	public func getFirstModelsAndTheirStocks(count: Int) async -> [ModelAndItsStocks] {
		guard count <= modelItemsByModelCode.keys.count else {fatalError()}
		let modelCodes = Array(modelItemsByModelCode.keys)[0..<count]
		return modelCodes.map{
			let items = modelItemsByModelCode[$0]!
			let stocks = items.reduce(into: [String: Int](minimumCapacity: items.count)){
				let itemCode = $1.itemCode365
				let stock = stockByItemCode[itemCode]!.stock
				$0[itemCode] = stock
			}
			return .init(model: items, stocks: stocks)
		}
	}
	public func getModel(modelCode: String) async -> [PSItem]? {
		return modelItemsByModelCode[modelCode]
	}
	public func getModelMetadata(modelCode: String) async -> PSListModel? {
		return modelsMetadataByModelCode[modelCode]
	}
	
	public func getAllModelsCount() async -> Int? {
		return modelItemsByModelCode.keys.count
	}
	
	public func getModelsPage(page: Int) async -> [PSListModel]? {
		return allModelsMetadata.getPaginatedSlice(pageNumber: page, pageSize: pageCapacity)
	}
	
	public func getAllModels() async -> [PSListModel]? {
		return allModelsMetadata
	}
	
	public func getStock(for itemCode: String) async -> PSListStockStoresItem? {
		return stockByItemCode[itemCode]
	}
	
	public func getAllStockCount() async -> Int? {
		return stockByItemCode.values.count
	}
	
	public func getStocksPage(page: Int) async -> [PSListStockStoresItem]? {
		return await allStocks.getPaginatedSlice(pageNumber: page, pageSize: pageCapacity)
	}
	
	public func getAllStocks() async -> [PSListStockStoresItem]? {
		return Array(stockByItemCode.values)
	}
	
	
	
}
extension Collection{
	func firstResult<T>(where producedThing: (Element)->T?)->T?{
		for item in self{
			if let thing = producedThing(item){
				return thing
			}
		}
		return nil
	}
}
extension Array{
	public func getPaginatedSlice(pageNumber: Int, pageSize: Int) -> [Element]? {
		guard pageNumber>0 else {return nil}
		
		let indexOffset = (pageNumber-1)*pageSize
		guard indexOffset>=0 else {return nil}
		
		let lastReachableIndex = self.count-1
		let lastWantedIndex = Swift.min(lastReachableIndex, indexOffset+pageSize-1)
		assert(indexOffset<=lastWantedIndex)
		let slice = self[indexOffset...lastWantedIndex]
		return Array(slice)
		
		
		/**
		 page 1:
		 start	end
		 item0	item99
		 itemsToSkip: 0
		 
		 page2:
		 start	end
		 item100	item199
		 itemsToSkip: 100 ([0]->[99])
		 
		 page 3:
		 start	end
		 item200	item299
		 itemsToSkip: 200([0]->[199])
		 
		 page n:
		 start			end
		 item[(n-1)*100]	item[(n-1)*100+99]
		 itemsToSkip: (n-1)*100
		 */
	}
}
extension Dictionary where Value: RangeReplaceableCollection{
	func allValuesAsOneCollection()->Value{
		let s = Value()
		return values.reduce(into: s){bigassCollection, collection in
			bigassCollection.append(contentsOf: collection)
		}
	}
}
