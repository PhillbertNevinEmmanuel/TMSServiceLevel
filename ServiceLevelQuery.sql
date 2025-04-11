SELECT 
    soh.[Id],
    da.[Id] AS DriverAssignmentId,    
    uep.[PrincipalName],
    soh.[TransactionCode],
    CASE
        WHEN sohe.[ClientTransNo] = '' AND soh.[StatusId] = 7 THEN REPLACE(soh.[TransactionCode], 'SO', 'SI')
        ELSE sohe.[ClientTransNo]
    END AS ClientTransNo,
    sos.[Label],
    soh.[TotalPrice],
    sod.[SKUId],
    ps.[SKUCode],
    se.[ItemName],
    sod.[RequestedQuantity],
    se.[MainUOMCode],
    CASE
        WHEN (sod.[PrintoutQty] IS NULL OR sod.[PrintoutUOM] IS NULL) AND se.[MainUOMCode] = 'CRT' THEN sod.[RequestedQuantity]
        WHEN sod.[PrintoutUOM] = 'CRT' THEN sod.[PrintoutQty]
        ELSE 0
    END AS PrintoutQtyCRT,
    CASE
        WHEN (sod.[PrintoutQty] IS NULL OR sod.[PrintoutUOM] IS NULL) AND se.[MainUOMCode] = 'PCK' THEN sod.[RequestedQuantity]
        WHEN sod.[PrintoutUOM] = 'PCK' THEN sod.[PrintoutQty]
        ELSE 0
    END AS PrintoutQtyPCK,
    CASE
        WHEN (sod.[PrintoutQty] IS NULL OR sod.[PrintoutUOM] IS NULL) AND se.[MainUOMCode] = 'PCS' THEN sod.[RequestedQuantity]
        WHEN (sod.[PrintoutQty] IS NULL OR sod.[PrintoutUOM] IS NULL) AND se.[MainUOMCode] = 'EA' THEN sod.[RequestedQuantity]   
        WHEN sod.[PrintoutUOM] = 'PCS' THEN sod.[PrintoutQty]      
        WHEN sod.[PrintoutUOM] = 'EA' THEN sod.[PrintoutQty]
        ELSE 0
    END AS PrintoutQtyPCS,
    sod.[CurrSKUPrice] AS CurrSKUPriceNonPPN,
    CASE
        WHEN (sohe.[IncludeTax] = 'False' AND stit.[TaxType] = 'NonPKP') OR (sohe.[IncludeTax] = 'False' AND stit.[TaxType] = 'PKP')
        THEN sod.[CurrSKUPrice] / 1.11
        ELSE sod.[CurrSKUPrice]
    END AS CurrSKUPrice,  
    das.[Label] AS ShipmentStatus, 
    dad.[CBMSize],
    dad.[WeigthKG],
    CASE 
        WHEN dad.[RequestedDate] IS NULL THEN soh.[CutOffDate]        
        ELSE dad.[RequestedDate]
    END AS RequestedDate,
    da.[VehicleId],    
    v.[LicenseNum],        
    d.[Id] AS DriverId,    
    d.[Name] AS DriverName,    
    d.[ContactNumber],
    zdd.[Id] AS ZoneId,
    CASE
        WHEN z.[ZoneName] IS NULL THEN br.[BranchName]
        ELSE z.[ZoneName]
    END AS ZoneName,
    CASE 
        WHEN z.[WarehouseId] IS NULL THEN soh.[WarehouseId]
        ELSE z.[WarehouseId]
    END AS WarehouseId,
    dsc.[UniqueCode],
    sd.[StoreName],
    sd.[IsActive],
    ues.[AccountCode] AS SalesCode,
    CASE
        WHEN ues.[UserId] IS NOT NULL THEN CONCAT(ues.[FirstName], ' ', ues.[LastName])
        ELSE NULL
    END AS SalesName,
    soh.[CutOffDate],
    soh.[DeliveredDate],
    CASE
        WHEN soh.[CutOffDate] <> '' AND soh.[DeliveredDate] <> '' AND soh.[CutOffDate] = CAST(soh.[DeliveredDate] AS DATE)
            THEN 'On Time'
        WHEN soh.[CutOffDate] <> '' AND soh.[DeliveredDate] <> '' AND soh.[CutOffDate] > CAST(soh.[DeliveredDate] AS DATE)
            THEN 'On Time'
        WHEN soh.[CutOffDate] <> '' AND soh.[DeliveredDate] <> '' AND soh.[CutOffDate] < CAST(soh.[DeliveredDate] AS DATE)
            THEN 'Late'        
        WHEN soh.[CutOffDate] > GETDATE() AND soh.[DeliveredDate] = ''
            THEN 'Delivery Process Incomplete'
        WHEN soh.[CutOffDate] <> '' AND soh.[DeliveredDate] = '' AND soh.[StatusId] IN (1, 2, 3, 6, 8, 11)
            THEN 'Delivery Process Incomplete'
           WHEN soh.[CutOffDate] <> '' AND soh.[DeliveredDate] = '' AND soh.[StatusId] IN (7) AND sor.[Id] <> '' OR sor.[Id] IS NOT NULL
            THEN 'Goods Sent With Return'
        WHEN soh.[CutOffDate] <> '' AND soh.[DeliveredDate] = '' AND soh.[StatusId] IN (7, 10, 13, 16, 17)
            THEN 'Goods Not Sent'     
        ELSE 'Unknown'
    END AS ServiceLevel
FROM {Sales_Order_Header} soh    
INNER JOIN {Sales_Order_Status} sos ON soh.[StatusId] = sos.[Id]
INNER JOIN {Sales_Order_Header_Extension} sohe ON soh.[Id] = sohe.[Id]
INNER JOIN {Sales_Order_Detail} sod ON soh.[Id] = sod.[SalesOrderId]
LEFT OUTER JOIN {Sales_Order_Return} sor ON (sor.[SalesOrderId] = soh.[Id] AND sor.[Status] IN (4, 6)
    AND sor.[RequestDate] = (
        SELECT MAX(sor1.[RequestDate])
        FROM {Sales_Order_Return} sor1
        WHERE sor1.[SalesOrderId] = sor.[SalesOrderId])
    )
INNER JOIN {Branch} br ON soh.[BranchId] = br.[Id]
INNER JOIN {SKU_Extension} se ON sod.[SKUId] = se.[Id]
INNER JOIN {SKU_Principal_Origin} spo ON sod.[SKUId] = spo.[SKUId]
INNER JOIN {Principal_SKU} ps ON spo.[PrincipalSKUId] = ps.[Id]
INNER JOIN {User_Extensions_Principal} uep ON ps.[PrincipalID] = uep.[Id]
INNER JOIN {Store_Details} sd ON soh.[StoreId] = sd.[Id]
INNER JOIN {Store_Tax_Invoice_Type} stit ON sd.[TaxType] = stit.[Id]
INNER JOIN {Distributor_Store_Connector} dsc ON sd.[Id] = dsc.[StoreId]
LEFT OUTER JOIN {User_Extensions_Sales} ues ON soh.[SalesId] = ues.[UserId]
INNER JOIN {Driver_Assignment_Detail} dad ON soh.[Id] = dad.[SalesOrderId]
INNER JOIN {Driver_Assignment} da ON dad.[DriverAssignmentId] = da.[Id]
INNER JOIN {Driver_Assignment_Status} das ON da.[Status] = das.[Id]
INNER JOIN {Vehicle} v ON da.[VehicleId] = v.[Id]
INNER JOIN {Driver} d ON v.[DriverId] = d.[Id]
INNER JOIN {Zone_Detail_Driver} zdd ON d.[Id] = zdd.[DriverId]
INNER JOIN {Zone} z ON zdd.[ZoneId] = z.[Id]
WHERE soh.[Dist_TenantId] = 34    
    AND soh.[IsActive] = 'True'
    AND sod.[IsRemoved] = 'False'
    AND dsc.[IsActive] = 'True'
    AND dad.[RequestedDate] >= @begin_date
ORDER BY da.[Id]