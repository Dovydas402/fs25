----------------------------------------------------------------------------
----Author: ViperGTS96------------------------------------------------------
----------------------------------------------------------------------------
--------------------"The simplest design is the best design." --------------
----------------------------------------------------------------------------

StoreDeliveries = {};
StoreDeliveries.dir = g_currentModDirectory;
StoreDeliveries.ringFile = StoreDeliveries.dir.."i3d/ringSelector.i3d";
StoreDeliveries.markerFile = StoreDeliveries.dir.."i3d/spotMarker.i3d";
local modDescFile = loadXMLFile("modDesc", StoreDeliveries.dir.."modDesc.xml");
StoreDeliveries.title = getXMLString(modDescFile, "modDesc.title.en");
StoreDeliveries.author = getXMLString(modDescFile, "modDesc.author");
StoreDeliveries.version = getXMLString(modDescFile, "modDesc.version");
StoreDeliveries.setSpotSnd = createSample("setLocationSound");
StoreDeliveries.deliverySnd = createSample("deliverySound");
loadSample(StoreDeliveries.setSpotSnd, StoreDeliveries.dir.."sounds/setLocation.ogg", false);
loadSample(StoreDeliveries.deliverySnd, StoreDeliveries.dir.."sounds/purchase.ogg", false);
setSamplePitch(StoreDeliveries.setSpotSnd, 1.3);
setSamplePitch(StoreDeliveries.deliverySnd, 1.0);
StoreDeliveries.storedLocation = {};
StoreDeliveries.storedDirection = {};
StoreDeliveries.storedPerpDirection = {};
StoreDeliveries.storedRotation = {};
StoreDeliveries.lightControl = {1.5,0,0,0,false};
StoreDeliveries.ringColor = {1,0,1,0,false};
StoreDeliveries.btnDown = false;
StoreDeliveries.chargeForAnimals = false;
StoreDeliveries.money = {};
StoreDeliveries.money.text = "";
StoreDeliveries.money.addNotification = false;
StoreDeliveries.money.delivery = {};
StoreDeliveries.money.delivery.charge = 0;
StoreDeliveries.money.delivery.totalCharges = 0;
StoreDeliveries.money.delivery.wasCharged = false;
StoreDeliveries.money.delivery.rate = 0.025; --[%]
StoreDeliveries.money.rateString = "2.5"
StoreDeliveries.money.deliveryString = g_i18n:getText("notification_StoreDeliveries");
StoreDeliveries.money.delivery.maxCharge = 5000.0; -- $
StoreDeliveries.isLoaded = false;
addModEventListener(StoreDeliveries);
delete(modDescFile);
source(Utils.getFilename("src/storeLocationEvent.lua", g_currentModDirectory));
source(Utils.getFilename("src/storePurchaseEvent.lua", g_currentModDirectory));

function StoreDeliveries:deleteHotSpot()
	if g_currentMission.storeDeliveriesHotspot ~= nil then
		g_currentMission:removeMapHotspot(g_currentMission.storeDeliveriesHotspot);
		local i = -1;
		for index,spot in pairs(g_currentMission.mapHotspots) do
			if spot == g_currentMission.storeDeliveriesHotspot then
				g_currentMission.storeDeliveriesHotspot = nil;
				i = index;
			end;
		end;
		if i >=0 then 
			table.remove(g_currentMission.mapHotspots,i);
		end;
	end;
end;

function StoreDeliveries:createHotSpot(wX,wZ,tX,tY,tZ)
		StoreDeliveries:deleteHotSpot();
		local hotspot = PlaceableHotspot.new();
		local text = g_i18n:getText("pda_StoreDeliveries");
		hotspot:setName(text);
		hotspot:createIcon();
		local imageFilename = StoreDeliveries.dir.."icon_storeDeliveries.dds";
		hotspot.placeable = {
		getHotspot = function () return hotspot end, 
		getImageFilename = function () return imageFilename end,
		getOwnerFarmId = function () return 0 end,
		specializations = {},
		canBeSold = function () return false end
		};
		hotspot:setPlaceableType(PlaceableHotspot.TYPE.SHOP)
		hotspot:setWorldPosition(wX, wZ);
		tY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, tX, tY, tZ);
		hotspot:setTeleportWorldPosition(tX, tY, tZ);
		return hotspot;
end;

function StoreDeliveries:loadSelectionRing(deliveriesTable)
	deliveriesTable.selectionRing = loadI3DFile(StoreDeliveries.ringFile, false, false, false);
	deliveriesTable.selectionRing = getChildAt(deliveriesTable.selectionRing, 0);
	link(getRootNode(), deliveriesTable.selectionRing);
	setVisibility(deliveriesTable.selectionRing, false);
    setShaderParameter(getChildAt(deliveriesTable.selectionRing,0), "lightControl", unpack(StoreDeliveries.lightControl));
    setShaderParameter(getChildAt(deliveriesTable.selectionRing,0), "colorScale", unpack(StoreDeliveries.ringColor));
	setScale(getChildAt(deliveriesTable.selectionRing,0), 0.7, 1, 0.7);
end;

function StoreDeliveries:loadMarkers(deliveriesTable)
	local markersSource = loadSharedI3DFile(StoreDeliveries.markerFile, false, false);
	markersSource = getChildAt(markersSource, 0);
	local markerGroup = createTransformGroup("storeDeliveriesMarkers");
	deliveriesTable.markers = {getChildAt(markersSource, 0), getChildAt(markersSource, 1), getChildAt(markersSource, 2), getChildAt(markersSource, 3)};
	link(getRootNode(), markerGroup);
	for _, marker in pairs(deliveriesTable.markers) do
		link(markerGroup, marker);
	end;
	setVisibility(markerGroup, false);
	deliveriesTable.markers.markerGroup = markerGroup;
	delete(markersSource);
	deliveriesTable.markersSet = false;
end;

function StoreDeliveries:loadMap(savegame)
	g_currentMission.storeDeliveries = {};
	StoreDeliveries:loadSelectionRing(g_currentMission.storeDeliveries);
	StoreDeliveries:loadMarkers(g_currentMission.storeDeliveries);

	--*Note* There is more than 1 Store Delivery Location, only the first one is being modified.
	local storePlace = g_currentMission.storeSpawnPlaces[1];
	StoreDeliveries.storedLocation = {storePlace.startX, storePlace.startY, storePlace.startZ};
	StoreDeliveries.storedRotation = {storePlace.rotX, storePlace.rotY, storePlace.rotZ};
	StoreDeliveries.storedDirection = {storePlace.dirX, storePlace.dirY, storePlace.dirZ};
	StoreDeliveries.storedPerpDirection = {storePlace.dirPerpX, storePlace.dirPerpY, storePlace.dirPerpZ};
	FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, StoreDeliveries.saveSettings);
	FarmStats.changeFinanceStats = Utils.appendedFunction(FarmStats.changeFinanceStats, StoreDeliveries.changeFinanceStats);
	BuyVehicleData.buy = Utils.prependedFunction(BuyVehicleData.buy, StoreDeliveries.onVehicleBought);
	BuyPlaceableData.buy = Utils.prependedFunction(BuyPlaceableData.buy, StoreDeliveries.onObjectBought);
	local settingsLoaded = StoreDeliveries:loadSettings();
	local settingsLoadedString = "";
	if settingsLoaded then 
		settingsLoadedString = " : Custom 'Store Location' loaded";
	end;
	print("Load mod: "..StoreDeliveries.title.." : v"..StoreDeliveries.version.." by "..StoreDeliveries.author..settingsLoadedString);
	g_currentMission.storeDeliveriesSrcRef = self;
	self.updateStoreLocationEvent = StoreDeliveries.updateStoreLocationEvent;
    self.updateStorePurchaseEvent = StoreDeliveries.updateStorePurchaseEvent;
end;

function StoreDeliveries:postLoadMap()
	local storePlace = g_currentMission.storeSpawnPlaces[1];
	if StoreDeliveries.isLoaded and storePlace.teleportX ~= nil then
		local hotspot = StoreDeliveries:createHotSpot(storePlace.startX,storePlace.startZ,storePlace.teleportX,storePlace.teleportY,storePlace.teleportZ);
		g_currentMission.storeDeliveriesHotspot = hotspot;
		g_currentMission:addMapHotspot(hotspot);
		table.insert(g_currentMission.mapHotspots, hotspot);
		g_currentMission.storeDeliveriesSrcRef:updateStoreLocationEvent(storePlace.startX, storePlace.startY, storePlace.startZ, storePlace.rotX, storePlace.rotY, storePlace.rotZ,storePlace.dirX, storePlace.dirY, storePlace.dirZ,storePlace.dirPerpX, storePlace.dirPerpY, storePlace.dirPerpZ, storePlace.teleportX, storePlace.teleportY, storePlace.teleportZ);
	end;
end;
FSBaseMission.onFinishedLoading = Utils.appendedFunction(FSBaseMission.onFinishedLoading, StoreDeliveries.postLoadMap);

function StoreDeliveries:moneyListener()
	if StoreDeliveries.isLoaded then
	-----------------------------------------While in Menu --------------------------------------------------------
		if StoreDeliveries.money.delivery.wasCharged then
			StoreDeliveries.money.delivery.wasCharged = false;
			if g_localPlayer ~= nil and g_localPlayer.farmId ~= nil then
				if g_localPlayer.farmId ~= FarmManager.SPECTATOR_FARM_ID then
					if not g_currentMission.missionDynamicInfo.isMultiplayer then
						g_currentMission:addMoney(-StoreDeliveries.money.delivery.charge, g_localPlayer.farmId, MoneyType.OTHER);
					end;
				end;
			end;
			StoreDeliveries.money.delivery.charge = 0;
			playSample(StoreDeliveries.deliverySnd,1,0.6,0,0,0);
		end;
	--------------------------------------Post Menu Notification---------------------------------------------------
		if StoreDeliveries.money.delivery.totalCharges > 0 then
			if not g_gui:getIsGuiVisible() then
				StoreDeliveries.money.text = g_i18n:formatMoney(StoreDeliveries.money.delivery.totalCharges, 0, false, true);
				StoreDeliveries.money.addNotification = true;
				StoreDeliveries.money.delivery.totalCharges = 0;
				StoreDeliveries.money.priorDeduction = 0;
				g_currentMission.storeDeliveries.vehicleBought = nil;
			end;
		end;
	---------------------------------------------------------------------------------------------------------------
	end;
end;

function StoreDeliveries:alignMarkerToGround(node)
    local x1,y1,z1 = localToWorld(node,0,0,5);
    local x2,y2,z2 = localToWorld(node,0,0,-5);
    local x3,y3,z3 = localToWorld(node,5,0,0);
    local x4,y4,z4 = localToWorld(node,-5,0,0);
    y1 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x1,y1,z1);
    y2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x2,y2,z2);
    y3 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x3,y3,z3);
    y4 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x4,y4,z4);
    local dirX = x2 - x1;
    local dirY = y2 - y1;
    local dirZ = z2 - z1;
    local dir2X = x3 - x4;
    local dir2Y = y3 - y4;
    local dir2Z = z3 - z4;
    local upX,upY,upZ = MathUtil.crossProduct(dir2X, dir2Y, dir2Z, dirX, dirY, dirZ);
    setDirection(getChildAt(node,0), dirX, dirY, dirZ, upX,upY,upZ);
end;

function StoreDeliveries:onVehicleBought()
	g_currentMission.storeDeliveries.vehicleBought = true;
	g_currentMission.storeDeliveries.farmId = self.ownerFarmId;
end;

function StoreDeliveries:onObjectBought()
	g_currentMission.storeDeliveries.farmId = self.ownerFarmId;
end;

function StoreDeliveries:updater()
	local inputOff = false;
	if Input.isKeyPressed(Input.KEY_lshift) then
		if Input.isKeyPressed(Input.KEY_lalt) then
			local cam = getCamera();
			local sRing = g_currentMission.storeDeliveries.selectionRing;
			local x,y,z = localToWorld(cam,0,0,-10);
			y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x,y,z);
			setWorldTranslation(sRing, x,y+0.15,z);
			StoreDeliveries:alignMarkerToGround(sRing);
			if not getVisibility(sRing) then setVisibility(sRing, true); end;
			if Input.isKeyPressed(Input.KEY_q) and not StoreDeliveries.btnDown then
				local storePlace = g_currentMission.storeSpawnPlaces[1];
				local dx,_,dz = localDirectionToWorld(cam,0,0,1);
				local rx,ry,rz = getWorldRotation(cam);
				local tX,tY,tZ = getWorldTranslation(cam);
				storePlace.startX, storePlace.startY, storePlace.startZ = x,y,z;
				storePlace.rotX, storePlace.rotY, storePlace.rotZ = rx,ry,rz;
				storePlace.dirX, storePlace.dirY, storePlace.dirZ = dz,0,-dx;--x&z are mirrored
				storePlace.dirPerpX, storePlace.dirPerpY, storePlace.dirPerpZ = dx,0,dz;
				storePlace.teleportX, storePlace.teleportY, storePlace.teleportZ = tX,tY,tZ;
				StoreDeliveries.btnDown = true;
				setVisibility(sRing, false);
				local hotspot = StoreDeliveries:createHotSpot(x,z,tX,tY,tZ);
				g_currentMission.storeDeliveriesHotspot = hotspot;
				g_currentMission:addMapHotspot(hotspot);
				table.insert(g_currentMission.mapHotspots, hotspot);
				StoreDeliveries.isLoaded = true;
				playSample(StoreDeliveries.setSpotSnd,1,0.6,0,0,0);
				g_currentMission.storeDeliveriesSrcRef:updateStoreLocationEvent(storePlace.startX, storePlace.startY, storePlace.startZ, storePlace.rotX, storePlace.rotY, storePlace.rotZ,storePlace.dirX, storePlace.dirY, storePlace.dirZ,storePlace.dirPerpX, storePlace.dirPerpY, storePlace.dirPerpZ, storePlace.teleportX, storePlace.teleportY, storePlace.teleportZ);
				g_currentMission.storeDeliveries.markersSet = false;
			elseif Input.isKeyPressed(Input.KEY_x) and not StoreDeliveries.btnDown then
				local storePlace = g_currentMission.storeSpawnPlaces[1];
				storePlace.startX, storePlace.startY, storePlace.startZ = unpack(StoreDeliveries.storedLocation);
				storePlace.rotX, storePlace.rotY, storePlace.rotZ = unpack(StoreDeliveries.storedRotation);
				storePlace.dirX, storePlace.dirY, storePlace.dirZ = unpack(StoreDeliveries.storedDirection);
				storePlace.dirPerpX, storePlace.dirPerpY, storePlace.dirPerpZ = unpack(StoreDeliveries.storedPerpDirection);
				storePlace.teleportX, storePlace.teleportY, storePlace.teleportZ = nil,nil,nil;
				StoreDeliveries.btnDown = true;
				setVisibility(sRing, false);
				StoreDeliveries:deleteHotSpot();
				StoreDeliveries.isLoaded = false;
				g_currentMission.storeDeliveriesSrcRef:updateStoreLocationEvent(storePlace.startX, storePlace.startY, storePlace.startZ, storePlace.rotX, storePlace.rotY, storePlace.rotZ,storePlace.dirX, storePlace.dirY, storePlace.dirZ,storePlace.dirPerpX, storePlace.dirPerpY, storePlace.dirPerpZ, 0,0,0);
			end;
		else
			inputOff = true;
		end;
	else
		inputOff = true;
	end;

	if inputOff then
		if g_currentMission.storeDeliveries == nil then
			StoreDeliveries:loadMap();
		end;
		if getVisibility(g_currentMission.storeDeliveries.selectionRing) then
			setVisibility(g_currentMission.storeDeliveries.selectionRing, false);
			setWorldTranslation(g_currentMission.storeDeliveries.selectionRing, 0,0,0);
		end;
		if StoreDeliveries.btnDown then
			StoreDeliveries.btnDown = false;
		end;
	end;

end;

function StoreDeliveries:changeFinanceStats(amount, statType)
	local isServerNoGUI = g_currentMission.missionDynamicInfo.isMultiplayer;
    if isServerNoGUI then isServerNoGUI = g_currentMission:getIsServer(); end;
    if StoreDeliveries.isLoaded and (g_gui:getIsGuiVisible() or isServerNoGUI) then
		local itemPurchase = false;
		local other = false;
		if statType ~= nil then
			local SD_Money = StoreDeliveries.money.delivery;
			for _, statTypeName in pairs({"other","purchaseSeeds","purchaseFertilizer","purchaseSaplings"}) do
				if statTypeName == statType then 
					itemPurchase = true;
					if statType == "other" then
						other = true;
					end;
					break;
				end;
			end;
			if not StoreDeliveries.chargeForAnimals then
				if itemPurchase and other then
					if string.upper(tostring(FocusManager.currentGui)) == "ANIMALSCREEN" then
						itemPurchase = false;
					end;
				end;
			end;
			if (amount*-1.0) > 25.0 then
				if statType == "newVehiclesCost" or statType == "vehicleLeasingCost" or itemPurchase then
					if g_currentMission.storeDeliveries.vehicleBought ~= nil then
						local netCost = (amount*-1.0)*SD_Money.rate;
						if netCost > SD_Money.maxCharge then netCost = SD_Money.maxCharge; end;
						SD_Money.charge = netCost;
						SD_Money.totalCharges = SD_Money.totalCharges + SD_Money.charge;
						SD_Money.wasCharged = true;
						if g_currentMission.missionDynamicInfo.isMultiplayer then
							if g_currentMission.storeDeliveries.farmId ~= nil then
								StoreDeliveries:updateStorePurchaseEvent(SD_Money.charge, SD_Money.totalCharges, g_currentMission.storeDeliveries.farmId);
								g_currentMission.storeDeliveries.farmId = nil;
							end;
						end;
					end;
				end;
			end;
		end;
	end;
end;

function StoreDeliveries:draw()
	if StoreDeliveries.isLoaded then
		if StoreDeliveries.money.addNotification then
			local rateString = StoreDeliveries.money.rateString;
			local deliveryCostString = StoreDeliveries.money.deliveryString;
			local currency = "$";
			if g_languageShort ~= "en" then
				currency = "€";
			end;
			local text = "- "..StoreDeliveries.money.text.." "..currency.." : "..deliveryCostString.." ("..rateString.."%)";
			g_currentMission.hud:addSideNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, text, nil, GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION);
			StoreDeliveries.money.addNotification = false;
		end;
	end;
end;

function StoreDeliveries:updateMarkers(gStoreDeliveries)
	if StoreDeliveries.isLoaded then
		if not gStoreDeliveries.markersSet then
			local markers = gStoreDeliveries.markers;
			local markersGroup = gStoreDeliveries.markers.markerGroup;
						
			local storePlace = g_currentMission.storeSpawnPlaces[1];
			setWorldTranslation(markersGroup, storePlace.startX,storePlace.startY,storePlace.startZ);
			setWorldDirection(markersGroup, -storePlace.dirZ,0,storePlace.dirX, storePlace.dirPerpX,0,storePlace.dirPerpZ);
			local x,z = math.min(28,storePlace.width)/2, math.min(24,storePlace.length)/2;
			setTranslation(markers[1], -x, 0, -z);
			setTranslation(markers[2], -x, 0, z);
			setTranslation(markers[3], x, 0, -z);
			setTranslation(markers[4], x, 0, z);

			for i=1, 4 do
				local mX,mY,mZ = getWorldTranslation(markers[i]);
				mY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, mX,mY,mZ)+0.01;
				setWorldTranslation(markers[i], mX,mY,mZ);
			end;

			setVisibility(markersGroup, true);

			gStoreDeliveries.markersSet = true;
		end;
	else
		if gStoreDeliveries.markersSet then
			setVisibility(gStoreDeliveries.markers.markerGroup, false);
			gStoreDeliveries.markersSet = false;
		end;
	end;
end;


function StoreDeliveries:update(dt)
	StoreDeliveries:updater();
	StoreDeliveries:moneyListener();
	StoreDeliveries:updateMarkers(g_currentMission.storeDeliveries);
end;

function StoreDeliveries:deleteMap(savegame)
	StoreDeliveries.storedLocation = {};
	StoreDeliveries.storedRotation = {};
	StoreDeliveries.storedDirection = {};
	StoreDeliveries.storedPerpDirection = {};
	StoreDeliveries.money.text = "";
	StoreDeliveries.money.delivery.charge = 0;
	StoreDeliveries.money.delivery.totalCharges = 0;
	StoreDeliveries.money.addNotification = false;
	StoreDeliveries.isLoaded = false;
	StoreDeliveries.btnDown = false;	
	StoreDeliveries.money.delivery.wasCharged = false;
end;

function StoreDeliveries:saveSettings()

	local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
	if savegameFolderPath == nil then
		savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex);
	end;
	savegameFolderPath = savegameFolderPath.."/"
	local key = "storeDeliveries";
	local storePlace = g_currentMission.storeSpawnPlaces[1];
	local xmlFile = createXMLFile(key, savegameFolderPath.."storeDeliveries.xml", key);
	setXMLBool(xmlFile, key.."#isLoaded", StoreDeliveries.isLoaded);
	setXMLFloat(xmlFile, key..".storeLocation#x", storePlace.startX);
	setXMLFloat(xmlFile, key..".storeLocation#y", storePlace.startY);
	setXMLFloat(xmlFile, key..".storeLocation#z", storePlace.startZ);
	setXMLFloat(xmlFile, key..".storeRotation#x", storePlace.rotX);
	setXMLFloat(xmlFile, key..".storeRotation#y", storePlace.rotY);
	setXMLFloat(xmlFile, key..".storeRotation#z", storePlace.rotZ);
	setXMLFloat(xmlFile, key..".storeDirection#x", storePlace.dirX);
	setXMLFloat(xmlFile, key..".storeDirection#y", storePlace.dirY);
	setXMLFloat(xmlFile, key..".storeDirection#z", storePlace.dirZ);
	setXMLFloat(xmlFile, key..".storePerpDirection#x", storePlace.dirPerpX);
	setXMLFloat(xmlFile, key..".storePerpDirection#y", storePlace.dirPerpY);
	setXMLFloat(xmlFile, key..".storePerpDirection#z", storePlace.dirPerpZ);
	if storePlace.teleportX ~= nil then
		setXMLFloat(xmlFile, key..".storeTeleportLocation#x", storePlace.teleportX);
		setXMLFloat(xmlFile, key..".storeTeleportLocation#y", storePlace.teleportY);
		setXMLFloat(xmlFile, key..".storeTeleportLocation#z", storePlace.teleportZ);
	end;
	saveXMLFile(xmlFile);

	delete(xmlFile);

end;

function StoreDeliveries:loadSettings()

	local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
	if savegameFolderPath == nil then
		savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex);
	end;
	savegameFolderPath = savegameFolderPath.."/"
	local key = "storeDeliveries";

	if fileExists(savegameFolderPath.."storeDeliveries.xml") then
		local xmlFile = loadXMLFile(key, savegameFolderPath.."storeDeliveries.xml");
		StoreDeliveries.isLoaded = getXMLBool(xmlFile, key.."#isLoaded");
		if StoreDeliveries.isLoaded then
			local storePlace = g_currentMission.storeSpawnPlaces[1];
			storePlace.startX = getXMLFloat(xmlFile, key..".storeLocation#x");
			storePlace.startY = getXMLFloat(xmlFile, key..".storeLocation#y");
			storePlace.startZ = getXMLFloat(xmlFile, key..".storeLocation#z");
			storePlace.rotX = getXMLFloat(xmlFile, key..".storeRotation#x");
			storePlace.rotY = getXMLFloat(xmlFile, key..".storeRotation#y");
			storePlace.rotZ = getXMLFloat(xmlFile, key..".storeRotation#z");
			storePlace.dirX = getXMLFloat(xmlFile, key..".storeDirection#x");
			storePlace.dirY = getXMLFloat(xmlFile, key..".storeDirection#y");
			storePlace.dirZ = getXMLFloat(xmlFile, key..".storeDirection#z");
			storePlace.dirPerpX = getXMLFloat(xmlFile, key..".storePerpDirection#x");
			storePlace.dirPerpY = getXMLFloat(xmlFile, key..".storePerpDirection#y");
			storePlace.dirPerpZ = getXMLFloat(xmlFile, key..".storePerpDirection#z");
			storePlace.teleportX = getXMLFloat(xmlFile, key..".storeTeleportLocation#x");
			storePlace.teleportY = getXMLFloat(xmlFile, key..".storeTeleportLocation#y");
			storePlace.teleportZ = getXMLFloat(xmlFile, key..".storeTeleportLocation#z");
		end;
		delete(xmlFile);
	end;

	return StoreDeliveries.isLoaded;

end;

function StoreDeliveries:updateStoreLocationEvent(startX, startY, startZ, rotX, rotY, rotZ, dirX, dirY, dirZ, dirPerpX, dirPerpY, dirPerpZ, tX,tY,tZ, noEventSend)
	storeLocationEvent.sendEvent(startX, startY, startZ, rotX, rotY, rotZ, dirX, dirY, dirZ, dirPerpX, dirPerpY, dirPerpZ, tX,tY,tZ, noEventSend);
	if not self.isServer then
		local storePlace = g_currentMission.storeSpawnPlaces[1];
		storePlace.startX, storePlace.startY, storePlace.startZ = startX, startY, startZ;
		storePlace.rotX, storePlace.rotY, storePlace.rotZ = rotX, rotY, rotZ;
		storePlace.dirX, storePlace.dirY, storePlace.dirZ = dirX, dirY, dirZ;
		storePlace.dirPerpX, storePlace.dirPerpY, storePlace.dirPerpZ = dirPerpX, dirPerpY, dirPerpZ;
		if not (tX==0 and tY==0 and tZ==0) then
			storePlace.teleportX, storePlace.teleportY, storePlace.teleportZ = tX,tY,tZ;
			if g_currentMission.storeDeliveriesHotspot == nil then
				local hotspot = StoreDeliveries:createHotSpot(storePlace.startX,storePlace.startZ,storePlace.teleportX,storePlace.teleportY,storePlace.teleportZ);
				g_currentMission.storeDeliveriesHotspot = hotspot;
				g_currentMission:addMapHotspot(hotspot);
				table.insert(g_currentMission.mapHotspots, hotspot);
			end;
			StoreDeliveries.isLoaded = true;
			g_currentMission.storeDeliveries.markersSet = false;
		else
			storePlace.teleportX, storePlace.teleportY, storePlace.teleportZ = nil,nil,nil;
			if g_currentMission.storeDeliveriesHotspot ~= nil then
				StoreDeliveries:deleteHotSpot();
			end;
			StoreDeliveries.isLoaded = false;
		end;
	else
		if not (tX==0 and tY==0 and tZ==0) then
			StoreDeliveries.isLoaded = true;
		else
			StoreDeliveries.isLoaded = false;
		end;
	end;
end;

function StoreDeliveries:updateStorePurchaseEvent(charge, totalCharges, farmId, noEventSend)
	storePurchaseEvent.sendEvent(charge, totalCharges, farmId, noEventSend);
		StoreDeliveries.money.delivery.wasCharged = true;
		StoreDeliveries.money.delivery.charge = charge;
		StoreDeliveries.money.delivery.totalCharges = totalCharges;
	if g_currentMission:getIsServer() then
		if farmId ~= nil then
			g_currentMission:addMoney(-StoreDeliveries.money.delivery.charge, farmId, MoneyType.OTHER);
		end;
	end;
end;

--[[
function StoreDeliveries:onConnectionWriteUpdateStream(connection, maxPacketSize, networkDebug)
	if not connection:getIsServer() then
		streamWriteBool(streamId, StoreDeliveries.isLoaded);

		local storePlace = g_currentMission.storeSpawnPlaces[1];

		streamWriteFloat32(streamId, storePlace.startX);
		streamWriteFloat32(streamId, storePlace.startY);
		streamWriteFloat32(streamId, storePlace.startZ);

		streamWriteFloat32(streamId, storePlace.rotX);
		streamWriteFloat32(streamId, storePlace.rotY);
		streamWriteFloat32(streamId, storePlace.rotZ);

		streamWriteFloat32(streamId, storePlace.dirX);
		streamWriteFloat32(streamId, storePlace.dirY);
		streamWriteFloat32(streamId, storePlace.dirZ);
		
		streamWriteFloat32(streamId, storePlace.dirPerpX);
		streamWriteFloat32(streamId, storePlace.dirPerpY);
		streamWriteFloat32(streamId, storePlace.dirPerpZ);
		
		streamWriteFloat32(streamId, storePlace.teleportX);
		streamWriteFloat32(streamId, storePlace.teleportY);
		streamWriteFloat32(streamId, storePlace.teleportZ);

	end;
end;

function StoreDeliveries:onConnectionReadUpdateStream(connection, networkDebug)
	if connection:getIsServer() then
		StoreDeliveries.isLoaded = streamReadBool(streamId);
		
		local storePlace = g_currentMission.storeSpawnPlaces[1];

		storePlace.startX = streamReadFloat32(streamId);
		storePlace.startY = streamReadFloat32(streamId);
		storePlace.startZ = streamReadFloat32(streamId);
		
		storePlace.rotX = streamReadFloat32(streamId);
		storePlace.rotY = streamReadFloat32(streamId);
		storePlace.rotZ = streamReadFloat32(streamId);
		
		storePlace.dirX = streamReadFloat32(streamId);
		storePlace.dirY = streamReadFloat32(streamId);
		storePlace.dirZ = streamReadFloat32(streamId);
		
		storePlace.dirPerpX = streamReadFloat32(streamId);
		storePlace.dirPerpY = streamReadFloat32(streamId);
		storePlace.dirPerpZ = streamReadFloat32(streamId);
		
		storePlace.teleportX = streamReadFloat32(streamId);
		storePlace.teleportY = streamReadFloat32(streamId);
		storePlace.teleportZ = streamReadFloat32(streamId);
	end;
end;

FSBaseMission.onConnectionWriteUpdateStream = Utils.appendedFunction(FSBaseMission.onConnectionWriteUpdateStream, StoreDeliveries.onConnectionWriteUpdateStream);
FSBaseMission.onConnectionReadUpdateStream = Utils.appendedFunction(FSBaseMission.onConnectionReadUpdateStream, StoreDeliveries.onConnectionReadUpdateStream);

]]
