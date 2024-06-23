//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftRTC open source project
//
// Copyright (c) 2024 ngRTC and the SwiftRTC project authors
// Licensed under MIT License
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftRTC project authors
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

// https://tools.ietf.org/html/rfc4346#section-6.2.1
public enum ContentType: UInt8, Equatable {
    case invalid = 0
    case changeCipherSpec = 20
    case alert = 21
    case handshake = 22
    case applicationData = 23
}
/*
impl From<u8> for ContentType {
    fn from(val: u8) -> Self {
        match val {
            20 => ContentType::ChangeCipherSpec,
            21 => ContentType::Alert,
            22 => ContentType::Handshake,
            23 => ContentType::ApplicationData,
            _ => ContentType::Invalid,
        }
    }
}

#[derive(PartialEq, Debug, Clone)]
pub enum Content {
    ChangeCipherSpec(ChangeCipherSpec),
    Alert(Alert),
    Handshake(Handshake),
    ApplicationData(ApplicationData),
}

impl Content {
    pub fn content_type(&self) -> ContentType {
        match self {
            Content::ChangeCipherSpec(c) => c.content_type(),
            Content::Alert(c) => c.content_type(),
            Content::Handshake(c) => c.content_type(),
            Content::ApplicationData(c) => c.content_type(),
        }
    }

    pub fn size(&self) -> usize {
        match self {
            Content::ChangeCipherSpec(c) => c.size(),
            Content::Alert(c) => c.size(),
            Content::Handshake(c) => c.size(),
            Content::ApplicationData(c) => c.size(),
        }
    }

    pub fn marshal<W: Write>(&self, writer: &mut W) -> Result<()> {
        match self {
            Content::ChangeCipherSpec(c) => c.marshal(writer),
            Content::Alert(c) => c.marshal(writer),
            Content::Handshake(c) => c.marshal(writer),
            Content::ApplicationData(c) => c.marshal(writer),
        }
    }

    pub fn unmarshal<R: Read>(content_type: ContentType, reader: &mut R) -> Result<Self> {
        match content_type {
            ContentType::ChangeCipherSpec => Ok(Content::ChangeCipherSpec(
                ChangeCipherSpec::unmarshal(reader)?,
            )),
            ContentType::Alert => Ok(Content::Alert(Alert::unmarshal(reader)?)),
            ContentType::Handshake => Ok(Content::Handshake(Handshake::unmarshal(reader)?)),
            ContentType::ApplicationData => Ok(Content::ApplicationData(
                ApplicationData::unmarshal(reader)?,
            )),
            _ => Err(Error::ErrInvalidContentType),
        }
    }
}
*/
