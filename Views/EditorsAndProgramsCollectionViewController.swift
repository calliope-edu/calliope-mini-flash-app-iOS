//
//  EditorsAndProgramsCollectionViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 02.06.19.
//

import UIKit

class EditorsAndProgramsCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, ProgramShareDelegate {

	private let reuseIdentifierWebEditor = "webEditorCell"
	private let reuseIdentifierOfflineEditor = "localEditorCell"
	private let reuseIdentifierPlayground = "playgroundCell"
	private let reuseIdentifierProgram = "editableProgramCell"

	private let reuseIdentifierHeader = "headerWithButton"

	private var makeCodeCell: EditorCollectionViewCell?
	private var robertaCell: EditorCollectionViewCell?
	private var playgroundCell: EditorCollectionViewCell?
	private var offlineEditorCell: EditorCollectionViewCell?

	private lazy var hexFiles = { () -> [HexFile] in
		do {
			return try HexFileManager.stored()
		}
		catch {
			LOG(error)
			fatalError("could not load files")
		}
	}()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.navigationController?.setNavigationBarHidden(true, animated: animated)
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		self.collectionViewLayout.invalidateLayout()
	}

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		if section == 0 {
			return 4
		} else {
			return hexFiles.count
		}
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell: UICollectionViewCell
		if indexPath.first == 0 {
			switch indexPath.row {
			case 0:
				cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierWebEditor, for: indexPath)
				robertaCell = cell as? EditorCollectionViewCell
				robertaCell?.button.setTitle("Roberta", for: UIControl.State.normal)
			case 1:
				cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierWebEditor, for: indexPath)
					makeCodeCell = cell as? EditorCollectionViewCell
					makeCodeCell?.button.setTitle("MakeCode", for: UIControl.State.normal)
			case 2:
				cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierPlayground, for: indexPath)
				playgroundCell = cell as? EditorCollectionViewCell
			case 3:
				cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierOfflineEditor, for: indexPath)
				offlineEditorCell = cell as? EditorCollectionViewCell
			default:
				fatalError("The program editor collection view features only 4 editors. numberOfItemsInSection must be set to 4.")
			}
		} else {
			//TODO: Configure the cell
			cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierProgram, for: indexPath)
			(cell as! ProgramCollectionViewCell).program = hexFiles[indexPath.row]
			(cell as! ProgramCollectionViewCell).delegate = self
		}
    
        return cell
    }

	override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
		if kind == UICollectionView.elementKindSectionHeader {
			let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: reuseIdentifierHeader, for: indexPath)
			//TODO: Configure the view
			return view
		} else {
			fatalError("The collection view only has headers, not \(kind)s")
		}
	}

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

	// MARK: UICollectionViewDelegateFlowLayout

	let editorButtonSize: CGFloat = 180
	let programWidthThreshold = 500
	let spacing: CGFloat = 10

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		if indexPath.section == 0 {
			return CGSize(width: 180, height: 180)
		} else {
			let width = collectionView.frame.size.width
			if width > 500 {
				return CGSize(width: width / 2.0 - 15, height: 100)
			} else {
				return CGSize(width: width - 20, height: 100)
			}
		}
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
		if section == 0 {
			let width = collectionView.frame.size.width
			let maxItems = width / (editorButtonSize + spacing)
			if maxItems < 2 {
				return UIEdgeInsets.zero
			} else if maxItems < 4 {
				let remainingSpace = width - 2 * editorButtonSize - spacing
				return UIEdgeInsets(top: 0, left: remainingSpace / 2, bottom: 0, right: remainingSpace / 2)
			} else {
				let remainingSpace = width - 4 * editorButtonSize - 3 * spacing
				return UIEdgeInsets(top: 0, left: remainingSpace / 2, bottom: 0, right: remainingSpace / 2)
			}
		} else {
			return UIEdgeInsets(top: 0, left: spacing, bottom: 0, right: spacing)
		}
	}

	// MARK: - Navigation

	// In a storyboard-based application, you will often want to do a little preparation before navigation
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if sender as? UIButton == makeCodeCell?.button {
			(segue.destination as? EditorViewController)?.editor = MicrobitEditor()
		} else if sender as? UIButton == robertaCell?.button {
			(segue.destination as? EditorViewController)?.editor = RobertaEditor()
		}
		// Get the new view controller using [segue destinationViewController].
		// Pass the selected object to the new view controller.
	}

	// MARK: ProgramShareDelegate

	func share(cell: ProgramCollectionViewCell) {
		let program = cell.program!
		let activityItems = [program, program.name, program.date, program.url, program.bin()] as [Any]

		let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
		activityViewController.modalTransitionStyle = UIModalTransitionStyle.coverVertical

		activityViewController.popoverPresentationController?.sourceRect = cell.shareButton.frame
		activityViewController.popoverPresentationController?.sourceView = cell

		self.present(activityViewController, animated: true, completion: nil)
	}
}
