import Foundation

struct MultipartFormDataBuilder {
    private let boundary: String
    private var parts: [Data] = []

    init(boundary: String) {
        self.boundary = boundary
    }

    func appendField(name: String, value: String) -> MultipartFormDataBuilder {
        var copy = self
        var data = Data()
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(value)\r\n".data(using: .utf8)!)
        copy.parts.append(data)
        return copy
    }

    func appendFile(fieldName: String, file: UploadFile) -> MultipartFormDataBuilder {
        var copy = self
        var data = Data()
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(file.contentType)\r\n\r\n".data(using: .utf8)!)
        data.append(file.data)
        data.append("\r\n".data(using: .utf8)!)
        copy.parts.append(data)
        return copy
    }

    func build() -> Data {
        var data = Data()
        for part in parts {
            data.append(part)
        }
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }
}
