//
//  Globe.swift
//  CesiumKit
//
//  Created by Ryan Walklin on 15/06/14.
//  Copyright (c) 2014 Test Toast. All rights reserved.
//

import Foundation

/**
* The globe rendered in the scene, including its terrain ({@link Globe#terrainProvider})
* and imagery layers ({@link Globe#imageryLayers}).  Access the globe using {@link Scene#globe}.
*
* @alias Globe
* @constructor
*
* @param {Ellipsoid} [ellipsoid=Ellipsoid.WGS84] Determines the size and shape of the
* globe.
*/
class Globe {
    
    let ellipsoid: Ellipsoid
    
    /**
    * The terrain provider providing surface geometry for this globe.
    * @type {TerrainProvider}
    */
    var terrainProvider: TerrainProvider
    
    var imageryLayerCollection: ImageryLayerCollection
    
    var surfaceShaderSet: GlobeSurfaceShaderSet
    
    var surface: QuadtreePrimitive
    
    var occluder: Occluder
    
    var _rsColor: RenderState? = nil
    var _rsColorWithoutDepthTest: RenderState? = nil
    
    var _clearDepthCommand: ClearCommand
    
    var _depthCommand: DrawCommand
    
    var _northPoleCommand: DrawCommand
    
    var _southPoleCommand: DrawCommand
    
    var drawNorthPole = false
    var drawSouthPole = false
    
    /**
    * Determines the color of the north pole. If the day tile provider imagery does not
    * extend over the north pole, it will be filled with this color before applying lighting.
    *
    * @type {Cartesian3}
    * @default Cartesian3(2.0 / 255.0, 6.0 / 255.0, 18.0 / 255.0)
    */
    var northPoleColor = Cartesian4(x: 2.0 / 255.0, y: 6.0 / 255.0, z: 18.0 / 255.0, w: 1.0)
    
    /**
    * Determines the color of the south pole. If the day tile provider imagery does not
    * extend over the south pole, it will be filled with this color before applying lighting.
    *
    * @type {Cartesian3}
    * @default Cartesian3(1.0, 1.0, 1.0)
    */
    var southPoleColor = Cartesian4(x: 1.0, y: 1.0, z: 1.0, w: 1.0)
    
    /**
    * Determines if the globe will be shown.
    *
    * @type {Boolean}
    * @default true
    */
    var show = true
    
    private var _mode = SceneMode.Scene3D
    
    /**
    * The normal map to use for rendering waves in the ocean.  Setting this property will
    * only have an effect if the configured terrain provider includes a water mask.
    *
    * @type {String}
    * @default buildModuleUrl('Assets/Textures/waterNormalsSmall.jpg')
    */
    var oceanNormalMapUrl: String = /*buildModuleUrl*/("Assets/Textures/waterNormalsSmall.jpg")
    
    private var lastOceanNormalMapUrl: String = ""
    
    /**
    * True if primitives such as billboards, polylines, labels, etc. should be depth-tested
    * against the terrain surface, or false if such primitives should always be drawn on top
    * of terrain unless they're on the opposite side of the globe.  The disadvantage of depth
    * testing primitives against terrain is that slight numerical noise or terrain level-of-detail
    * switched can sometimes make a primitive that should be on the surface disappear underneath it.
    *
    * @type {Boolean}
    * @default false
    */
    var depthTestAgainstTerrain = false
    
    /**
    * The maximum screen-space error used to drive level-of-detail refinement.  Higher
    * values will provide better performance but lower visual quality.
    *
    * @type {Number}
    * @default 2
    */
    var maximumScreenSpaceError = 2
    
    /**
    * The size of the terrain tile cache, expressed as a number of tiles.  Any additional
    * tiles beyond this number will be freed, as long as they aren't needed for rendering
    * this frame.  A larger number will consume more memory but will show detail faster
    * when, for example, zooming out and then back in.
    *
    * @type {Number}
    * @default 100
    */
    var tileCacheSize = 100
    
    /**
    * Enable lighting the globe with the sun as a light source.
    *
    * @type {Boolean}
    * @default false
    */
    var enableLighting = false
    
    /**
    * The distance where everything becomes lit. This only takes effect
    * when <code>enableLighting</code> is <code>true</code>.
    *
    * @type {Number}
    * @default 6500000.0
    */
    var lightingFadeOutDistance = 6500000.0
    
    /**
    * The distance where lighting resumes. This only takes effect
    * when <code>enableLighting</code> is <code>true</code>.
    *
    * @type {Number}
    * @default 9000000.0
    */
    var lightingFadeInDistance = 9000000.0
    
    //this._oceanNormalMap = undefined;
    
    var _zoomedOutOceanSpecularIntensity = 0.5
    
    private var _showingPrettyOcean = false
    
    private var _hasWaterMask = false
    
    private var _hasVertexNormals = false

    private var _lightingFadeDistance: Cartesian2
    
    lazy var drawUniforms: Dictionary<String, ()->Any> = {
        
        weak var weakSelf = self
        return [
            /*"u_zoomedOutOceanSpecularIntensity": { return weakSelf._zoomedOutOceanSpecularIntensity },
            "u_oceanNormalMap" : { return weakSelf.oceanNormalMap },*/
            "u_lightingFadeDistance" :  { return weakSelf!._lightingFadeDistance }
        ]
        }()
    
    init(ellipsoid: Ellipsoid = Ellipsoid.wgs84Ellipsoid()) {
        
        self.ellipsoid = ellipsoid
        terrainProvider = EllipsoidTerrainProvider(ellipsoid : ellipsoid)
        imageryLayerCollection = ImageryLayerCollection()
        
        occluder = Occluder(occluderBoundingSphere: BoundingSphere(center: Cartesian3.zero(), radius: ellipsoid.minimumRadius), cameraPosition: Cartesian3.zero())
        
        surfaceShaderSet = GlobeSurfaceShaderSet(attributeLocations: ["position3DAndHeight": 0, "textureCoordinates": 1])
        
        surface = QuadtreePrimitive(
            tileProvider: GlobeSurfaceTileProvider(
                terrainProvider: terrainProvider,
                imageryLayers: imageryLayerCollection,
                surfaceShaderSet: surfaceShaderSet
            )
        )
        _lightingFadeDistance = Cartesian2(x: lightingFadeOutDistance, y: lightingFadeInDistance)
        
        _clearDepthCommand = ClearCommand(depth: 1.0, stencil: 0/*, owner: self*/)
        _depthCommand = DrawCommand(
            boundingVolume: BoundingSphere(center: Cartesian3.zero(), radius: Ellipsoid.wgs84Ellipsoid().maximumRadius),
            pass: Pass.Opaque//,
            /*owner: self*/)
        _northPoleCommand = DrawCommand(pass: Pass.Opaque/*, owner: self*/)
        _southPoleCommand = DrawCommand(pass: Pass.Opaque/*, owner: self*/)
    }
    
    func createComparePickTileFunction(rayOrigin: Cartesian3) -> ((GlobeSurfaceTile, GlobeSurfaceTile) -> Double) {
        func comparePickTileFunction(a: GlobeSurfaceTile, b: GlobeSurfaceTile) -> Double {
            var aDist = a.pickBoundingSphere.distanceSquaredTo(rayOrigin)
            var bDist = b.pickBoundingSphere.distanceSquaredTo(rayOrigin)
            return aDist - bDist
        }
        return comparePickTileFunction
    }
    
    /**
    * Find an intersection between a ray and the globe surface that was rendered. The ray must be given in world coordinates.
    *
    * @param {Ray} ray The ray to test for intersection.
    * @param {Scene} scene The scene.
    * @param {Cartesian3} [result] The object onto which to store the result.
    * @returns {Cartesian3|undefined} The intersection or <code>undefined</code> if none was found.
    *
    * @example
    * // find intersection of ray through a pixel and the globe
    * var ray = scene.camera.getPickRay(windowCoordinates);
    * var intersection = globe.pick(ray, scene);
    */
    func pick(ray: Ray, scene: Scene) -> Cartesian3? {
        //FIXME: Unimplemented
        /*
        var scratchArray = [];
        var scratchSphereIntersectionResult = Interval)
        start : 0.0,
        stop : 0.0
        )
        //>>includeStart('debug', pragmas.debug);
        if (!defined(ray)) {
        throw new DeveloperError('ray is required');
        }
        if (!defined(scene)) {
        throw new DeveloperError('scene is required');
        }
        //>>includeEnd('debug');
        
        var mode = scene.mode;
        var projection = scene.mapProjection;
        
        var sphereIntersections = scratchArray;
        sphereIntersections.length = 0;
        
        var tilesToRender = this._surface._tilesToRender;
        var length = tilesToRender.length;
        
        var tile;
        var i;
        
        for (i = 0; i < length; ++i) {
        tile = tilesToRender[i];
        var tileData = tile.data;
        
        if (!defined(tileData)) {
        continue;
        }
        
        var boundingVolume = tileData.pickBoundingSphere;
        if (mode !== SceneMode.SCENE3D) {
        BoundingSphere.fromRectangleWithHeights2D(tile.rectangle, projection, tileData.minimumHeight, tileData.maximumHeight, boundingVolume);
        Cartesian3.fromElements(boundingVolume.center.z, boundingVolume.center.x, boundingVolume.center.y, boundingVolume.center);
        } else {
        BoundingSphere.clone(tileData.boundingSphere3D, boundingVolume);
        }
        
        var boundingSphereIntersection = IntersectionTests.raySphere(ray, boundingVolume, scratchSphereIntersectionResult);
        if (defined(boundingSphereIntersection)) {
        sphereIntersections.push(tileData);
        }
        }
        
        sphereIntersections.sort(createComparePickTileFunction(ray.origin));
        
        var intersection;
        length = sphereIntersections.length;
        for (i = 0; i < length; ++i) {
        intersection = sphereIntersections[i].pick(ray, scene, true, result);
        if (defined(intersection)) {
        break;
        }
        }
        
        return intersection;*/ return Cartesian3()
    }
    
    /**
    * Get the height of the surface at a given cartographic.
    *
    * @param {Cartographic} cartographic The cartographic for which to find the height.
    * @returns {Number|undefined} The height of the cartographic or undefined if it could not be found.
    */
    func getHeight(cartographic: Cartographic) -> Double? {
        //FIXME: Unimplemented
        /*
        var scratchGetHeightCartesian = new Cartesian3();
        var scratchGetHeightIntersection = new Cartesian3();
        var scratchGetHeightCartographic = new Cartographic();
        var scratchGetHeightRay = new Ray();
        //>>includeStart('debug', pragmas.debug);
        if (!defined(cartographic)) {
        throw new DeveloperError('cartographic is required');
        }
        //>>includeEnd('debug');
        
        var levelZeroTiles = this._surface._levelZeroTiles;
        if (!defined(levelZeroTiles)) {
        return;
        }
        
        var tile;
        var i;
        
        var length = levelZeroTiles.length;
        for (i = 0; i < length; ++i) {
        tile = levelZeroTiles[i];
        if (Rectangle.contains(tile.rectangle, cartographic)) {
        break;
        }
        }
        
        if (!defined(tile) || !Rectangle.contains(tile.rectangle, cartographic)) {
        return undefined;
        }
        
        while (tile.renderable) {
        var children = tile.children;
        length = children.length;
        
        for (i = 0; i < length; ++i) {
        tile = children[i];
        if (Rectangle.contains(tile.rectangle, cartographic)) {
        break;
        }
        }
        }
        
        while (defined(tile) && (!defined(tile.data) || !defined(tile.data.pickTerrain))) {
        tile = tile.parent;
        }
        
        if (!defined(tile)) {
        return undefined;
        }
        
        var ellipsoid = this._surface._tileProvider.tilingScheme.ellipsoid;
        var cartesian = ellipsoid.cartographicToCartesian(cartographic, scratchGetHeightCartesian);
        
        var ray = scratchGetHeightRay;
        Cartesian3.normalize(cartesian, ray.direction);
        
        var intersection = tile.data.pick(ray, undefined, false, scratchGetHeightIntersection);
        if (!defined(intersection)) {
        return undefined;
        }
        
        return ellipsoid.cartesianToCartographic(intersection, scratchGetHeightCartographic).height;*/return 0.0
    }

    func computeDepthQuad(#frameState: FrameState) -> [Float] {
        
        var depthQuad = [Float](count: 12, repeatedValue: 0.0)//(count: 12, repeatedValue: 0.0)
        
        var radii = ellipsoid.radii
        
        // Find the corresponding position in the scaled space of the ellipsoid.
        var q = ellipsoid.oneOverRadii.multiplyComponents(frameState.camera!.positionWC)
        
        var qMagnitude = q.magnitude()
        var qUnit = q.normalize()
        
        // Determine the east and north directions at q.
        var eUnit = q.cross(Cartesian3.unitZ()).normalize()
        var nUnit = qUnit.cross(eUnit).normalize()
        
        // Determine the radius of the 'limb' of the ellipsoid.
        var wMagnitude = sqrt(q.magnitudeSquared() - 1.0)
        
        // Compute the center and offsets.
        var center = qUnit.multiplyByScalar(qMagnitude)
        var scalar = wMagnitude / qMagnitude;
        var eastOffset = eUnit.multiplyByScalar(scalar)
        var northOffset = nUnit.multiplyByScalar(scalar)
        
        // A conservative measure for the longitudes would be to use the min/max longitudes of the bounding frustum.
        var upperLeft = center.add(northOffset).subtract(eastOffset).multiplyComponents(radii)
        var lowerLeft = center.subtract(northOffset).subtract(eastOffset).multiplyComponents(radii)
        var upperRight = center.add(northOffset).add(eastOffset).multiplyComponents(radii)
        var lowerRight = center.subtract(northOffset).add(eastOffset).multiplyComponents(radii)
        
        upperLeft.pack(&depthQuad, startingIndex: 0)
        lowerLeft.pack(&depthQuad, startingIndex: 3)
        upperRight.pack(&depthQuad, startingIndex: 6)
        lowerRight.pack(&depthQuad, startingIndex: 9)
        
        return depthQuad
    }
    
    func computePoleQuad(#frameState: FrameState, maxLat: Double, maxGivenLat: Double, viewProjMatrix: Matrix4, viewportTransformation: Matrix4) -> BoundingRectangle {
        //FIXME: PoleQuad
        /*
        let negativeZ = Cartesian3.unitZ().negate()
        
        var pt1 = ellipsoid.cartographicToCartesian(Cartographic(0.0, maxGivenLat))
        var pt2 = ellipsoid.cartographicToCartesian(Cartographic(M_PI, maxGivenLat))
        var radius = pt1.subtract(pt2).magnitude() * 0.5
        
        var center = ellipsoid.cartographicToCartesian(Cartographic(0.0, maxLat));
        
        var right: Cartesian3
        var dir = frameState.camera.direction
        if (1.0 - negativeZ.dot(dir) < Math.Epsilon6) {
            right = Cartesian3.unitX()
        } else {
            right = dir.cross(Cartesian3.unitX()).normalize()
        }
        
        var screenRight = center.add(right.multiplyByScalar(radius))
        var screenUp = center.add(Cartesian3.unitZ().cross(right).normalize().multiplyByScalar(radius))
        
        Transforms.pointToWindowCoordinates(viewProjMatrix, viewportTransformation, center, center)
        Transforms.pointToWindowCoordinates(viewProjMatrix, viewportTransformation, screenRight, screenRight)
        Transforms.pointToWindowCoordinates(viewProjMatrix, viewportTransformation, screenUp, screenUp)
        
        var halfWidth = floor(max(screenUp.distance(center), screenRight.distance(center)))
        var halfHeight = halfWidth
        */
        return BoundingRectangle()
            /*floor(center.x) - halfWidth,
            floor(center.y) - halfHeight,
            halfWidth * 2.0,
            halfHeight * 2.0)*/
 
    }
    
    func fillPoles(#context: Context, frameState: FrameState) {
        //FIXME: Fillpoles
        /*
        var viewportScratch = BoundingRectangle()
        var vpTransformScratch = Matrix()
        var polePositionsScratch = Float32[](count: 8, repeatedValue: 0.0)
        
        var terrainProvider = surface.terrainProvider
        if (frameState.mode != SceneMode.Scene3D) {
            return
        }
        
        if (!terrainProvider.ready) {
            return
        }
        var terrainMaxRectangle = terrainProvider.tilingScheme.rectangle
        
        var viewProjMatrix = context.uniformState.viewProjection
        var viewport = BoundingRectangle(width: context.drawingBufferWidth, height: context.drawingBufferHeight)
        var viewportTransformation = viewport.computeViewportTransformation(0.0, 1.0)
        var latitudeExtension = 0.05
        
        var rectangle: Rectangle
        var boundingVolume: Intersectable
        var frustumCull: Bool
        var occludeePoint: Cartesian3
        var occluded: Bool
        var geometry: Geometry?
        var rect: Rectangle?
        
        // handle north pole
        if (terrainMaxRectangle.north < M_PI_2) {
            rectangle = Rectangle(
                -M_PI,
                terrainMaxRectangle.north,
                M_PI,
                M_PI_2
            )
            boundingVolume = BoundingSphere.fromRectangle3D(rectangle, ellipsoid)
            frustumCull = frameState.cullingVolume.visibility(boundingVolume) == Intersect.Outside
            occludeePoint = Occluder.computeOccludeePointFromRectangle(rectangle, globe._ellipsoid);
            occluded = (occludeePoint && !occluder.isPointVisible(occludeePoint, 0.0)) || !occluder.isBoundingSphereVisible(boundingVolume);
            
            drawNorthPole = !frustumCull && !occluded;
            if (drawNorthPole) {
                rect = computePoleQuad(frameState: frameState, maxLat: rectangle.north, maxGivenLat: rectangle.south - latitudeExtension, viewProjMatrix: viewProjMatrix, viewportTransformation: viewportTransformation)
                polePositionsScratch[0] = rect.x;
                polePositionsScratch[1] = rect.y;
                polePositionsScratch[2] = rect.x + rect.width;
                polePositionsScratch[3] = rect.y;
                polePositionsScratch[4] = rect.x + rect.width;
                polePositionsScratch[5] = rect.y + rect.height;
                polePositionsScratch[6] = rect.x;
                polePositionsScratch[7] = rect.y + rect.height;
                
                if northPoleCommand.vertexArray == nil {
                    northPoleCommand.boundingVolume = BoundingSphere.fromRectangle3D(rectangle, globe._ellipsoid);

                    geometry = Geometry(geometryAttributes: GeometryAttributes(position: GeometryAttribute(componentDatatype: ComponentDatatype.Float32, componentsPerAttribute: 2, values: polePositionsScratch)))

                    northPoleCommand.vertexArray = context.createVertexArrayFromGeometry(geometry : geometry, attributeLocations : [position : 0], bufferUsage: BufferUsage.StreamDraw)
                } else {
                    globe.northPoleCommand.vertexArray.getAttribute(0).vertexBuffer.copyFromArrayView(polePositionsScratch);
                }
            }
        }
        
        // handle south pole
        if (terrainMaxRectangle.south > -CesiumMath.PI_OVER_TWO) {
            rectangle = Rectangle(
                -Math.PI,
                -CesiumMath.PI_OVER_TWO,
                Math.PI,
                terrainMaxRectangle.south
            );
            boundingVolume = BoundingSphere.fromRectangle3D(rectangle, globe._ellipsoid);
            frustumCull = frameState.cullingVolume.getVisibility(boundingVolume) === Intersect.OUTSIDE;
            occludeePoint = Occluder.computeOccludeePointFromRectangle(rectangle, globe._ellipsoid);
            occluded = (occludeePoint && !occluder.isPointVisible(occludeePoint)) || !occluder.isBoundingSphereVisible(boundingVolume);
            
            globe._drawSouthPole = !frustumCull && !occluded;
            if (globe._drawSouthPole) {
                rect = computePoleQuad(globe, frameState, rectangle.south, rectangle.north + latitudeExtension, viewProjMatrix, viewportTransformation);
                polePositionsScratch[0] = rect.x;
                polePositionsScratch[1] = rect.y;
                polePositionsScratch[2] = rect.x + rect.width;
                polePositionsScratch[3] = rect.y;
                polePositionsScratch[4] = rect.x + rect.width;
                polePositionsScratch[5] = rect.y + rect.height;
                polePositionsScratch[6] = rect.x;
                polePositionsScratch[7] = rect.y + rect.height;
                
                if (!defined(globe._southPoleCommand.vertexArray)) {
                    globe._southPoleCommand.boundingVolume = BoundingSphere.fromRectangle3D(rectangle, globe._ellipsoid);
                    geometry = Geometry(geometryAttributes: GeometryAttributes(position: GeometryAttribute(componentDatatype: ComponentDatatype.Float32, componentsPerAttribute: 2, values: polePositionsScratch)))
                    SouthPoleCommand.vertexArray = context.createVertexArrayFromGeometry(geometry : geometry, attributeLocations : [position : 0], bufferUsage: BufferUsage.StreamDraw)

                } else {
                    globe._southPoleCommand.vertexArray.getAttribute(0).vertexBuffer.copyFromArrayView(polePositionsScratch);
                }
            }
        }
        
        var poleIntensity = 0.0;
        var baseLayer = globe._imageryLayerCollection.length > 0 ? globe._imageryLayerCollection.get(0) : undefined;
        if (defined(baseLayer) && defined(baseLayer.imageryProvider) && defined(baseLayer.imageryProvider.getPoleIntensity)) {
            poleIntensity = baseLayer.imageryProvider.getPoleIntensity();
        }
        var drawUniforms = [
            "u_dayIntensity" :  { poleIntensity }
        ]
        weak var weakSelf = self
        if northPoleCommand.uniformMap != nil {
            var northPoleUniforms = drawUniforms + [ "u_color" : { weakSelf.northPoleColor } ]
            northPoleCommand.uniformMap += drawUniforms
        }
        
        if southPoleCommand.uniformMap != nil {
            var northPoleUniforms = drawUniforms + [ "u_color" : { weakSelf.southPoleColor } ]
            southPoleCommand.uniformMap += drawUniforms
        }*/
    }

/**
* @private
*/
    func update(context: Context, frameState: FrameState, commandList: [DrawCommand]) {
        if !show {
            return
        }

        var width = context.drawingBufferWidth
        var height = context.drawingBufferHeight
        
        if (width == 0 || height == 0) {
            return
        }
        
        var mode = frameState.mode
        var projection = frameState.mapProjection
        var modeChanged = false
        
        if _mode != mode || _rsColor == nil {
            modeChanged = true
            
            _rsColor = context.createRenderState() // Write color and depth
            _rsColor?.cull.enabled = true
            _rsColor?.depthTest.enabled = true
            
            _rsColorWithoutDepthTest = context.createRenderState()
            _rsColorWithoutDepthTest?.cull.enabled = true
            _depthCommand.renderState = context.createRenderState()
            _depthCommand.renderState?.cull.enabled = true
            
            if (mode == SceneMode.Scene3D || mode == SceneMode.ColumbusView) {
                _depthCommand.renderState?.depthTest.enabled = true
                _depthCommand.renderState?.depthTest.function = .Less
                _depthCommand.renderState?.colorMask = RenderState.ColorMask(red: false, green: false, blue: false, alpha: false)
            }
        }
        
        _northPoleCommand.renderState = _rsColorWithoutDepthTest
        _southPoleCommand.renderState = _rsColorWithoutDepthTest
        
        // update depth plane
        var depthQuad = computeDepthQuad(frameState: frameState)
        var depthIndices = [0, 1, 2, 2, 1, 3]
        
        // depth plane
        if _depthCommand.vertexArray == nil {
            var geometry = Geometry(
                    attributes: GeometryAttributes(
                        position: GeometryAttribute(
                            componentDatatype: ComponentDatatype.Float32,
                            componentsPerAttribute: 3,
                            values: SerializedArray(data: NSData.serializeArray(depthQuad), type: .Float32))
                        ),
                    indices : depthIndices,
                    primitiveType : PrimitiveType.Triangles
            )
            _depthCommand.vertexArray = context.createVertexArrayFromGeometry(
                geometry,
                attributeLocations: ["position": 0],
                bufferUsage: .DynamicDraw)
        } else {
            _depthCommand.vertexArray?.attribute(0).vertexBuffer?.copyFromArrayView(SerializedArray(data: NSData.serializeArray(depthQuad), type: .Float32))
        }
        
        if _depthCommand.shaderProgram == nil {
             _depthCommand.shaderProgram = context.createShaderProgram(vertexShaderSource: "GlobeVSDepth", fragmentShaderSource: "GlobeFSDepth", attributeLocations: ["position" : 0])
        }
        
        var hasWaterMask = surface.tileProvider.ready && surface.tileProvider.terrainProvider.hasWaterMask()
        var hasWaterMaskChanged = _hasWaterMask != hasWaterMask
        var hasVertexNormals = surface.tileProvider.ready && surface.tileProvider.terrainProvider.hasVertexNormals()
        var hasVertexNormalsChanged = _hasVertexNormals != hasVertexNormals
        //var hasEnableLightingChanged = _enableLighting != enableLighting
        
        /*if (this._surface.tileProvider.ready &&
            this._surface.tileProvider.terrainProvider.hasWaterMask &&
            this.oceanNormalMapUrl !== this._lastOceanNormalMapUrl) {
                
                this._lastOceanNormalMapUrl = this.oceanNormalMapUrl;
                
                var that = this;
                when(loadImage(this.oceanNormalMapUrl), function(image) {
                    that._oceanNormalMap = that._oceanNormalMap && that._oceanNormalMap.destroy();
                    that._oceanNormalMap = context.createTexture2D({
                        source : image
                    });
                    });
        }
        
        // Initial compile or re-compile if uber-shader parameters changed
        var hasVertexNormals = this._surface.tileProvider.ready && this._surface.tileProvider.terrainProvider.hasVertexNormals;
        var hasWaterMaskChanged = this._hasWaterMask !== hasWaterMask;
        var hasVertexNormalsChanged = this._hasVertexNormals !== hasVertexNormals;
        var hasEnableLightingChanged = this._enableLighting !== this.enableLighting;
        
        if (!defined(this._northPoleCommand.shaderProgram) ||
            !defined(this._southPoleCommand.shaderProgram) ||
            modeChanged ||
            hasWaterMaskChanged ||
            hasVertexNormalsChanged ||
            hasEnableLightingChanged ||
            (defined(this._oceanNormalMap)) !== this._showingPrettyOcean) {
                
                var getPosition3DMode = 'vec4 getPosition(vec3 position3DWC) { return getPosition3DMode(position3DWC); }';
                var getPosition2DMode = 'vec4 getPosition(vec3 position3DWC) { return getPosition2DMode(position3DWC); }';
                var getPositionColumbusViewMode = 'vec4 getPosition(vec3 position3DWC) { return getPositionColumbusViewMode(position3DWC); }';
                var getPositionMorphingMode = 'vec4 getPosition(vec3 position3DWC) { return getPositionMorphingMode(position3DWC); }';
                
                var getPositionMode;
                
                switch (mode) {
                case SceneMode.SCENE3D:
                    getPositionMode = getPosition3DMode;
                    break;
                case SceneMode.SCENE2D:
                    getPositionMode = getPosition2DMode;
                    break;
                case SceneMode.COLUMBUS_VIEW:
                    getPositionMode = getPositionColumbusViewMode;
                    break;
                case SceneMode.MORPHING:
                    getPositionMode = getPositionMorphingMode;
                    break;
                }
                
                var get2DYPositionFractionGeographicProjection = 'float get2DYPositionFraction() { return get2DGeographicYPositionFraction(); }';
                var get2DYPositionFractionMercatorProjection = 'float get2DYPositionFraction() { return get2DMercatorYPositionFraction(); }';
                
                var get2DYPositionFraction;
                
                if (projection instanceof GeographicProjection) {
                    get2DYPositionFraction = get2DYPositionFractionGeographicProjection;
                } else {
                    get2DYPositionFraction = get2DYPositionFractionMercatorProjection;
                }
                
                this._surfaceShaderSet.baseVertexShaderString = createShaderSource({
                    defines : [
                    (hasWaterMask ? 'SHOW_REFLECTIVE_OCEAN' : ''),
                    (this.enableLighting && !hasVertexNormals ? 'ENABLE_DAYNIGHT_SHADING' : ''),
                    (this.enableLighting && hasVertexNormals ? 'ENABLE_VERTEX_LIGHTING' : '')
                    ],
                    sources : [GlobeVS, getPositionMode, get2DYPositionFraction]
                });
                
                var showPrettyOcean = hasWaterMask && defined(this._oceanNormalMap);
                
                this._surfaceShaderSet.baseFragmentShaderString = createShaderSource({
                    defines : [
                    (hasWaterMask ? 'SHOW_REFLECTIVE_OCEAN' : ''),
                    (showPrettyOcean ? 'SHOW_OCEAN_WAVES' : ''),
                    (this.enableLighting && !hasVertexNormals ? 'ENABLE_DAYNIGHT_SHADING' : ''),
                    (this.enableLighting && hasVertexNormals ? 'ENABLE_VERTEX_LIGHTING' : '')
                    ],
                    sources : [GlobeFS]
                });
                this._surfaceShaderSet.invalidateShaders();
                
                var poleShaderProgram = context.replaceShaderProgram(this._northPoleCommand.shaderProgram,
                    GlobeVSPole, GlobeFSPole, terrainAttributeLocations);
                
                this._northPoleCommand.shaderProgram = poleShaderProgram;
                this._southPoleCommand.shaderProgram = poleShaderProgram;
                
                this._showingPrettyOcean = defined(this._oceanNormalMap);
                this._hasWaterMask = hasWaterMask;
                this._hasVertexNormals = hasVertexNormals;
                this._enableLighting = this.enableLighting;
        }
        
        var cameraPosition = frameState.camera.positionWC;
        
        this._occluder.cameraPosition = cameraPosition;
        
        fillPoles(this, context, frameState);
        
        this._mode = mode;
        
        var pass = frameState.passes;
        if (pass.render) {
            // render quads to fill the poles
            if (mode === SceneMode.SCENE3D) {
                if (this._drawNorthPole) {
                    commandList.push(this._northPoleCommand);
                }
                
                if (this._drawSouthPole) {
                    commandList.push(this._southPoleCommand);
                }
            }
            
            // Don't show the ocean specular highlights when zoomed out in 2D and Columbus View.
            if (mode === SceneMode.SCENE3D) {
                this._zoomedOutOceanSpecularIntensity = 0.5;
            } else {
                this._zoomedOutOceanSpecularIntensity = 0.0;
            }
            
            var surface = this._surface;
            surface.maximumScreenSpaceError = this.maximumScreenSpaceError;
            surface.tileCacheSize = this.tileCacheSize;
            
            var tileProvider = surface.tileProvider;
            tileProvider.terrainProvider = this.terrainProvider;
            tileProvider.lightingFadeOutDistance = this.lightingFadeOutDistance;
            tileProvider.lightingFadeInDistance = this.lightingFadeInDistance;
            tileProvider.zoomedOutOceanSpecularIntensity = this._zoomedOutOceanSpecularIntensity;
            tileProvider.oceanNormalMap = this._oceanNormalMap;
            
            this._surface.update(context, frameState, commandList);
            
            // render depth plane
            if (mode === SceneMode.SCENE3D || mode === SceneMode.COLUMBUS_VIEW) {
                if (!this.depthTestAgainstTerrain) {
                    commandList.push(this._clearDepthCommand);
                    if (mode === SceneMode.SCENE3D) {
                        commandList.push(this._depthCommand);
                    }
                }
            }
        }
        
        if (pass.pick) {
            // Not actually pickable, but render depth-only so primitives on the backface
            // of the globe are not picked.
            commandList.push(this._depthCommand);
        }*/
    }

/**
* Destroys the WebGL resources held by this object.  Destroying an object allows for deterministic
* release of WebGL resources, instead of relying on the garbage collector to destroy this object.
* <br /><br />
* Once an object is destroyed, it should not be used; calling any function other than
* <code>isDestroyed</code> will result in a {@link DeveloperError} exception.  Therefore,
* assign the return value (<code>undefined</code>) to the object as done in the example.
*
* @returns {undefined}
*
* @exception {DeveloperError} This object was destroyed, i.e., destroy() was called.
*
* @see Globe#isDestroyed
*
* @example
* globe = globe && globe.destroy();
*/
    deinit {
        /*this._northPoleCommand.vertexArray = this._northPoleCommand.vertexArray && this._northPoleCommand.vertexArray.destroy();
        this._southPoleCommand.vertexArray = this._southPoleCommand.vertexArray && this._southPoleCommand.vertexArray.destroy();
        
        this._surfaceShaderSet = this._surfaceShaderSet && this._surfaceShaderSet.destroy();
        
        this._northPoleCommand.shaderProgram = this._northPoleCommand.shaderProgram && this._northPoleCommand.shaderProgram.destroy();
        this._southPoleCommand.shaderProgram = this._northPoleCommand.shaderProgram;
        
        this._depthCommand.shaderProgram = this._depthCommand.shaderProgram && this._depthCommand.shaderProgram.destroy();
        this._depthCommand.vertexArray = this._depthCommand.vertexArray && this._depthCommand.vertexArray.destroy();
        
        this._surface = this._surface && this._surface.destroy();
        
        this._oceanNormalMap = this._oceanNormalMap && this._oceanNormalMap.destroy();
        
        return destroyObject(this);*/
    }
}

