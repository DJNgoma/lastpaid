import CoreData
import Foundation

enum PersistenceController {
    static func makePersistentContainer(inMemory: Bool = false) throws -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(
            name: "HowMuchModel",
            managedObjectModel: makeManagedObjectModel()
        )

        let description = NSPersistentStoreDescription()
        description.type = NSSQLiteStoreType
        description.shouldAddStoreAsynchronously = false
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            let baseURL = try makeStoreDirectory()
            description.url = baseURL.appendingPathComponent("HowMuch.sqlite")
        }

        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let loadError {
            throw loadError
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.undoManager = nil

        return container
    }

    private static func makeStoreDirectory() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL.appendingPathComponent("HowMuch", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let productEntity = NSEntityDescription()
        productEntity.name = "Product"
        productEntity.managedObjectClassName = NSStringFromClass(Product.self)

        let priceEntryEntity = NSEntityDescription()
        priceEntryEntity.name = "PriceEntry"
        priceEntryEntity.managedObjectClassName = NSStringFromClass(PriceEntry.self)

        let productID = makeAttribute(name: "id", type: .UUIDAttributeType)
        let barcodeValue = makeAttribute(name: "barcodeValue", type: .stringAttributeType)
        let barcodeTypeRaw = makeAttribute(name: "barcodeTypeRaw", type: .stringAttributeType)
        let customName = makeAttribute(name: "customName", type: .stringAttributeType)
        let brand = makeAttribute(name: "brand", type: .stringAttributeType, optional: true)
        let createdAt = makeAttribute(name: "createdAt", type: .dateAttributeType)
        let updatedAt = makeAttribute(name: "updatedAt", type: .dateAttributeType)
        let lastScannedAt = makeAttribute(name: "lastScannedAt", type: .dateAttributeType)

        let priceEntryID = makeAttribute(name: "id", type: .UUIDAttributeType)
        let amountStorage = makeAttribute(name: "amountStorage", type: .stringAttributeType)
        let currencyCode = makeAttribute(name: "currencyCode", type: .stringAttributeType)
        let storeName = makeAttribute(name: "storeName", type: .stringAttributeType, optional: true)
        let quantityText = makeAttribute(name: "quantityText", type: .stringAttributeType, optional: true)
        let notes = makeAttribute(name: "notes", type: .stringAttributeType, optional: true)
        let purchasedAt = makeAttribute(name: "purchasedAt", type: .dateAttributeType)
        let entryCreatedAt = makeAttribute(name: "createdAt", type: .dateAttributeType)
        let entryUpdatedAt = makeAttribute(name: "updatedAt", type: .dateAttributeType)

        let productToEntries = NSRelationshipDescription()
        productToEntries.name = "priceEntries"
        productToEntries.destinationEntity = priceEntryEntity
        productToEntries.minCount = 0
        productToEntries.maxCount = 0
        productToEntries.deleteRule = .cascadeDeleteRule
        productToEntries.isOptional = false
        productToEntries.isOrdered = false

        let entryToProduct = NSRelationshipDescription()
        entryToProduct.name = "product"
        entryToProduct.destinationEntity = productEntity
        entryToProduct.minCount = 0
        entryToProduct.maxCount = 1
        entryToProduct.deleteRule = .nullifyDeleteRule
        entryToProduct.isOptional = true

        productToEntries.inverseRelationship = entryToProduct
        entryToProduct.inverseRelationship = productToEntries

        productEntity.properties = [
            productID,
            barcodeValue,
            barcodeTypeRaw,
            customName,
            brand,
            createdAt,
            updatedAt,
            lastScannedAt,
            productToEntries
        ]
        productEntity.uniquenessConstraints = [["barcodeValue"]]
        productEntity.indexes = [
            makeFetchIndex(name: "productBarcodeIndex", property: barcodeValue)
        ]

        priceEntryEntity.properties = [
            priceEntryID,
            amountStorage,
            currencyCode,
            storeName,
            quantityText,
            notes,
            purchasedAt,
            entryCreatedAt,
            entryUpdatedAt,
            entryToProduct
        ]

        model.entities = [productEntity, priceEntryEntity]
        return model
    }

    private static func makeAttribute(
        name: String,
        type: NSAttributeType,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }

    private static func makeFetchIndex(
        name: String,
        property: NSPropertyDescription
    ) -> NSFetchIndexDescription {
        let element = NSFetchIndexElementDescription(property: property, collationType: .binary)
        return NSFetchIndexDescription(name: name, elements: [element])
    }
}
