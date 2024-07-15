//
//  EditorsCollectionViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 07.10.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

private let reuseIdentifier = "Cell"

class EditorsCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    private let reuseIdentifierMakeCode = "makecodeEditorCell"
    private let reuseIdentifierNepo = "nepoEditorCell"
    private let reuseIdentifierOfflineEditor = "localEditorCell"
    private let reuseIdentifierPlayground = "playgroundCell"
    private let reuseIdentifierCalliopeBlocks = "calliopeBlocksCell"

    private lazy var activatedEditors: [SettingsKey] = {
        var keys: [SettingsKey] = []
        let settings = UserDefaults.standard
        if settings.bool(forKey: SettingsKey.localEditor.rawValue) {
            keys.append(.localEditor)
        }
        if settings.bool(forKey: SettingsKey.makeCode.rawValue) {
            keys.append(.makeCode)
        }
        if settings.bool(forKey: SettingsKey.calliopeBlocks.rawValue) {
            keys.append(.calliopeBlocks)
        }
        if settings.bool(forKey: SettingsKey.playgrounds.rawValue) {
            keys.append(.playgrounds)
        }
        if settings.bool(forKey: SettingsKey.roberta.rawValue) {
            keys.append(.roberta)
        }
       
        return keys
        }()
    
    var heightConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        (collectionViewLayout as! UICollectionViewFlowLayout).estimatedItemSize = UICollectionViewFlowLayout.automaticSize
    }
    
    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return activatedEditors.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: UICollectionViewCell
        cell = createEditorCell(indexPath, collectionView)
        
        return cell
    }
    
    private func createEditorCell(_ indexPath: IndexPath, _ collectionView: UICollectionView) -> UICollectionViewCell {
        guard indexPath.row < activatedEditors.count else {
            fatalError("The program editor collection view features only \(activatedEditors.count) editors. numberOfItemsInSection must be set to that value.")
        }
        
        let cell: EditorCollectionViewCell
        let editorKey = activatedEditors[indexPath.row]
        
        switch editorKey {
        case .makeCode:
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierMakeCode, for: indexPath) as! EditorCollectionViewCell
        case .roberta:
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierNepo, for: indexPath) as! EditorCollectionViewCell
        case .playgrounds:
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierPlayground, for: indexPath) as! EditorCollectionViewCell
        case .localEditor:
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierOfflineEditor, for: indexPath) as! EditorCollectionViewCell
        case .calliopeBlocks:
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierCalliopeBlocks, for: indexPath) as! EditorCollectionViewCell
        default:
            fatalError("invalid key found in active editors array")
        }
        
        cell.editor = editorKey
        
        return cell
    }

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // MARK: UICollectionViewDelegateFlowLayout

    let editorButtonSize: CGFloat = 180
    let spacing: CGFloat = 10

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let width = collectionView.frame.size.width
        let maxItems = width / (editorButtonSize + spacing)
        let numEditors = CGFloat(activatedEditors.count)
        if maxItems <= 2 {
            // flowlayout centers single cells
            return UIEdgeInsets.zero
        } else if maxItems < numEditors {
            let remainingSpace = width - 2 * editorButtonSize - spacing
            return UIEdgeInsets(top: 0, left: remainingSpace / 2, bottom: 0, right: remainingSpace / 2)
        } else {
            let remainingSpace = width - numEditors * editorButtonSize - (numEditors - 1) * spacing
            return UIEdgeInsets(top: 0, left: remainingSpace / 2, bottom: 0, right: remainingSpace / 2)
        }
    }
    
    // MARK: - Navigation
    
    @IBSegueAction
    func createMakecodeEditor(coder: NSCoder, sender: Any?) -> EditorViewController? {
        EditorViewController(coder: coder, editor: MakeCode())
    }
    
    @IBSegueAction
    func createNepoEditor(coder: NSCoder, sender: Any?) -> EditorViewController? {
        EditorViewController(coder: coder, editor: RobertaEditor())
    }
}
