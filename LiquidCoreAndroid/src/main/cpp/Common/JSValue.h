//
// JSValue.h
//
// LiquidPlayer project
// https://github.com/LiquidPlayer
//
// Created by Eric Lange
//
/*
 Copyright (c) 2016 - 2018 Eric Lange. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 - Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
#ifndef LIQUIDCORE_JSVALUE_H
#define LIQUIDCORE_JSVALUE_H

#include "Common/JSContext.h"

using namespace v8;

class JSValue : public boost::enable_shared_from_this<JSValue> {
public:
    JSValue(boost::shared_ptr<JSContext> context, Local<v8::Value> val);
    JSValue();
    virtual ~JSValue();

    inline Local<v8::Value> Value ()
    {
        EscapableHandleScope scope(Isolate::GetCurrent());
        if (m_isUndefined) {
            Local<v8::Value> undefined =
                    Local<v8::Value>::New(isolate(),Undefined(isolate()));
            return scope.Escape(undefined);
        } else if (m_isNull) {
            Local<v8::Value> null =
                    Local<v8::Value>::New(isolate(),Null(isolate()));
            return scope.Escape(null);
        } else {
            return scope.Escape(Local<v8::Value>::New(isolate(), m_value));
        }
    }
    inline Isolate* isolate()
    {
        boost::shared_ptr<JSContext> context = m_context;
        return context ? context->isolate() : nullptr;
    }
    inline boost::shared_ptr<ContextGroup> Group()
    {
        boost::shared_ptr<JSContext> context = m_context;
        return context ? context->Group() : boost::shared_ptr<ContextGroup>();
    }
    inline boost::shared_ptr<JSContext> Context()  { return m_context; }

    inline bool IsDefunct() { return m_isDefunct; }
    inline bool IsUndefined() { return m_isUndefined; }
    inline bool IsNull() { return m_isNull; }
    inline bool IsObject() { return m_isObject; }
    inline bool IsBoolean() { return m_isBoolean; }
    inline bool IsNumber() { return m_isNumber; }
    inline bool IsTrue() { return m_booleanValue; }
    inline bool IsFalse() { return !m_booleanValue; }
    inline double NumberValue() { return m_numberValue; }

    void Dispose();

    static inline Local<v8::Value> Wrap(JSValue *value)
    {
        EscapableHandleScope scope(Isolate::GetCurrent());
        return scope.Escape(External::New(Isolate::GetCurrent(), value));
    }
    static inline JSValue* Unwrap(Local<v8::Value> identifier)
    {
        return reinterpret_cast<JSValue*>(identifier.As<External>()->Value());
    }

    static boost::shared_ptr<JSValue> New(boost::shared_ptr<JSContext> context, Local<v8::Value> val);

protected:
    Persistent<v8::Value> m_value;
    boost::atomic_shared_ptr<JSContext> m_context;
    bool m_isUndefined;
    bool m_isNull;
    bool m_wrapped;
    bool m_isObject;
    bool m_isNumber;
    double m_numberValue;
    bool m_isBoolean;
    bool m_booleanValue;

private:
    bool m_isDefunct = false;
};

#endif //LIQUIDCORE_JSVALUE_H
