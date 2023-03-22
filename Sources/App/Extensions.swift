//
//  Extensions.swift
//  
//
//  Created by Andreas Loizides on 03/03/2023.
//

import Foundation
extension Collection{
	func groupToDictionary<T: Hashable>(by property: KeyPath<Element,T>)->[T:[Element]]{
		return self.reduce(into: [T: [Element]]()){dict, element in
			let key = element[keyPath: property]
			dict[key, default: .init()].append(element)
		}
	}
	func toDictionary<T: Hashable>(by property: KeyPath<Element,T>)->Dictionary<T, Element>{
		return self.reduce(into: [T: Element]()){dict, element in
			let key = element[keyPath: property]
			dict[key] = element
		}
	}
}
