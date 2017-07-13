
import Foundation
import PromiseKit

fileprivate
func taskUpload(assets: [AssetImage],
                mainAsset: AssetImage? = nil) -> ( (ID) -> [Promise<ItemImage>] ) {
    return { itemId in
        return assets.map { asset in
            let assetURL = asset.fileURL
            let shouldSetAsMain = (asset == mainAsset)
            
            let task = Backend
                .fetch(resource: .addItemPhoto(itemId: itemId,
                                               type: .localURL(assetURL) ) )
            
            guard shouldSetAsMain else { return task }

            return task.then { resultItemImage in
                return Backend
                    .fetch(resource: .setPhotoMain(itemId: itemId,
                                                   imageId: resultItemImage.id))
            }
        }
    }
}

class ICWPresenter {
    weak var delegate: ICWDelegate?
    
    init(delegate: ICWDelegate) {
        self.delegate = delegate
    }
    
    func getTags() {
        Backend
            .fetch(resource: .tags())
            .then { tags in
                self.delegate?.showTags(tags: tags)
            }.catch { error in
                self.delegate?.showError(message: error.localizedDescription)
            }
    }
    
    func addItems(_ item: BlankItem) {
        delegate?.showLoader()
        
        Backend
            .fetch(resource: .create(item: item))
            .then { result in
                return when(fulfilled: taskUpload(assets: item.itemImages,
                                                  mainAsset: item.mainImage)(result.id))
            }.then { _ in
                self.delegate?.itemCreated(success: true)
            }.catch { error in
                self.delegate?.showError(message: error.localizedDescription)
            }.always {
                self.delegate?.hideLoader()
            }
    }
    
    func updateItems(_ item: BlankItem) {
        guard let id = item.id else {
            self.delegate?.showError(message: ServiceError.Unknown.localizedDescription)
            return
        }
        
        delegate?.showLoader()
    
        let promiseArray = taskUpload(assets: item.itemImages)(id)
        
        when(resolved: promiseArray)
            .then { _ in
                return Backend.fetch(resource: .update(itemId: id,
                                                       item: item))
            }.then { result  in
                self.delegate?.itemUpdated(item: result)
            }.catch { error in
                self.delegate?.showError(message: error.localizedDescription)
            }.always {
                self.delegate?.hideLoader()
            }
    }
}
