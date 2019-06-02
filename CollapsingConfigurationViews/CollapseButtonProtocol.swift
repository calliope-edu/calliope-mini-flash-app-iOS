//
//  CollapseButtonProtocol.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 04.05.19.
//

import UIKit

enum ExpansionState: Int {
	case open
	case closed
}

protocol CollapseButtonProtocol: class {
	var expansionState: ExpansionState { get set }
}
