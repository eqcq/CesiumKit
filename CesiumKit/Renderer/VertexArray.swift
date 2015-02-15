//
//  VertexArray.swift
//  CesiumKit
//
//  Created by Ryan Walklin on 15/06/14.
//  Copyright (c) 2014 Test Toast. All rights reserved.
//

import OpenGLES

class VertexArray {
    
    private var _attributes = [VertexAttributes]()
    
    var attributeCount: Int {
        return _attributes.count
    }
    
    let vertexCount: Int
    
    private var _vao: GLuint? = nil
    
    let indexBuffer: IndexBuffer?

    init(attributes: [VertexAttributes], indexBuffer: IndexBuffer?) {
        
        var vaAttributes = [VertexAttributes]()
        var numberOfVertices = 1  // if every attribute is backed by a single value
        self.vertexCount = numberOfVertices
        self.indexBuffer = indexBuffer

        for var i = 0; i < attributes.count; ++i {
            addAttribute(&vaAttributes, attribute: attributes[i], index: i)
        }
        
        for var i = 0; i < vaAttributes.count; ++i {
            var attribute = vaAttributes[i]
            
            if attribute.vertexBuffer != nil {
                // This assumes that each vertex buffer in the vertex array has the same number of vertices.
                var bytes = (attribute.strideInBytes != 0) ? attribute.strideInBytes : attribute.componentsPerAttribute * attribute.componentDatatype.elementSize()
                numberOfVertices = attribute.vertexBuffer!.sizeInBytes / bytes
                break
            }
        }
        
        // Verify all attribute names are unique
        var uniqueIndices = [Bool](count: vaAttributes.count, repeatedValue: false)
        for var j = 0; j < vaAttributes.count; ++j {
            var index = vaAttributes[j].index
            if (uniqueIndices[index]) {
                assert(!uniqueIndices[index], "Index \(index) is used by more than one attribute.")
            }
            uniqueIndices[index] = true
        }
        
        self._attributes = vaAttributes
        
        // Setup VAO
        var vao: GLuint = 0
        glGenVertexArrays(1, &vao)
        glBindVertexArray(vao)
        bind()
        glBindVertexArray(0)
        _vao = vao
    }
    
    private func addAttribute(inout attributes: [VertexAttributes], attribute: VertexAttributes, index: Int) {
        
        var hasVertexBuffer = attribute.vertexBuffer != nil
        var hasValue = attribute.value != nil
        var componentsPerAttribute = (attribute.value != nil) ? attribute.value!.length : attribute.componentsPerAttribute
        
        // FIXME: vertexbuffer.value
        assert(hasVertexBuffer != hasValue, "attribute must have a vertexBuffer or a value. It must have either a vertexBuffer property defining per-vertex data or a value property defining data for all vertices")
        
        assert(componentsPerAttribute >= 1 && componentsPerAttribute <= 4, "attribute.value.length must be in the range [1, 4]")

        /*if (defined(attribute.strideInBytes) && (attribute.strideInBytes > 255)) {
            // WebGL limit.  Not in GL ES.
            throw new DeveloperError('attribute must have a strideInBytes less than or equal to 255 or not specify it.');
        }*/
        var attr = attribute.copy()
        
        if (hasVertexBuffer) {
            // Common case: vertex buffer for per-vertex data
            attr.vertexAttrib = { (attr: VertexAttributes) in
                glBindBuffer(BufferTarget.ArrayBuffer.toGL(), attr.vertexBuffer!.buffer)
                glVertexAttribPointer(
                    GLuint(attr.index),
                    GLint(attr.componentsPerAttribute),
                    attr.componentDatatype.toGL(),
                    attr.normalize ? GLboolean(GL_TRUE) : GLboolean(GL_FALSE),
                    GLsizei(attr.strideInBytes),
                    UnsafePointer<Void>(bitPattern: attr.offsetInBytes)
                )
                glEnableVertexAttribArray(GLuint(attr.index))
            }
            
            attr.disableVertexAttribArray = { (attr: VertexAttributes) in
                glDisableVertexAttribArray(GLuint(attr.index))
            }
        } else {
            // Less common case: value array for the same data for each vertex
            /*switch (attr.componentsPerAttribute) {
            case 1:
                attr.vertexAttrib = function(gl) {
                    gl.vertexAttrib1fv(this.index, this.value);
                };
                break;
            case 2:
                attr.vertexAttrib = function(gl) {
                    gl.vertexAttrib2fv(this.index, this.value);
                };
                break;
            case 3:
                attr.vertexAttrib = function(gl) {
                    gl.vertexAttrib3fv(this.index, this.value);
                };
                break;
            case 4:
                attr.vertexAttrib = function(gl) {
                    gl.vertexAttrib4fv(this.index, this.value);
                };
                break;
            }
            
            attr.disableVertexAttribArray = function(gl) {
            };*/
        }
        
        attributes.append(attr)
    }
    
    private func bind() {
        
        for attribute in _attributes {
            if attribute.enabled {
                attribute.vertexAttrib(attr: attribute)
            }
        }

        if indexBuffer != nil {
            glBindBuffer(BufferTarget.ElementArrayBuffer.toGL(), indexBuffer!.buffer)
        }
    }

/*
defineProperties(VertexArray.prototype, {
numberOfAttributes : {
get : function() {
return this._attributes.length;
}

},
indexBuffer : {
get : function() {
return this._indexBuffer;
}
}
});
*/
/**
* index is the location in the array of attributes, not the index property of an attribute.
*/
    func attribute(index: Int) -> VertexAttributes {
        return _attributes[index]
    }

    func _bind() {
        if _vao != nil {
            glBindVertexArray(_vao!)
        } else {
                bind()
            }
    }

    func _unBind() {
        if _vao != nil {
            glBindVertexArray(0)
        } else {
            for attribute in _attributes {
                if attribute.enabled {
                    attribute.disableVertexAttribArray(attr: attribute)
                }
            }
            if indexBuffer != nil {
                glBindBuffer(BufferTarget.ElementArrayBuffer.toGL(), 0)
            }
        }
    }

    deinit {
        if _vao != nil {
            glDeleteVertexArrays(1, &_vao!)
        }
    }
}

