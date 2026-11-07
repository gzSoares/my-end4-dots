#include "mpvitem.h"

#include <clocale>

#include <QByteArray>
#include <QGuiApplication>
#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QQuickWindow>
#include <QVariantMap>
#include <qguiapplication_platform.h>

#include <mpv/client.h>
#include <mpv/render_gl.h>

MpvCore::~MpvCore() {
    if (handle) mpv_terminate_destroy(handle);
}

namespace {

void *procAddress(void *, const char *name) {
    auto *context = QOpenGLContext::currentContext();
    return context ? reinterpret_cast<void *>(context->getProcAddress(QByteArray(name))) : nullptr;
}

QVariant fromNode(const mpv_node &node) {
    switch (node.format) {
    case MPV_FORMAT_STRING: return QString::fromUtf8(node.u.string);
    case MPV_FORMAT_FLAG: return node.u.flag != 0;
    case MPV_FORMAT_INT64: return QVariant::fromValue(static_cast<qlonglong>(node.u.int64));
    case MPV_FORMAT_DOUBLE: return node.u.double_;
    case MPV_FORMAT_NODE_ARRAY: {
        QVariantList list;
        for (int i = 0; i < node.u.list->num; i++) list.append(fromNode(node.u.list->values[i]));
        return list;
    }
    case MPV_FORMAT_NODE_MAP: {
        QVariantMap map;
        for (int i = 0; i < node.u.list->num; i++)
            map.insert(QString::fromUtf8(node.u.list->keys[i]), fromNode(node.u.list->values[i]));
        return map;
    }
    default: return {};
    }
}

class MpvRenderer : public QQuickFramebufferObject::Renderer {
public:
    MpvRenderer(MpvItem *item, std::shared_ptr<MpvCore> core) : m_item(item), m_core(std::move(core)) {}

    ~MpvRenderer() override {
        if (m_context) mpv_render_context_free(m_context);
    }

    QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override {
        if (!m_context) init();
        return new QOpenGLFramebufferObject(size);
    }

    void render() override {
        if (!m_context) return;
        auto *target = framebufferObject();
        mpv_opengl_fbo fbo { static_cast<int>(target->handle()), target->width(), target->height(), 0 };
        int flip = 0;
        mpv_render_param params[] = {
            { MPV_RENDER_PARAM_OPENGL_FBO, &fbo },
            { MPV_RENDER_PARAM_FLIP_Y, &flip },
            { MPV_RENDER_PARAM_INVALID, nullptr },
        };
        mpv_render_context_render(m_context, params);
    }

private:
    void init() {
        mpv_opengl_init_params gl { procAddress, nullptr };
        const char *api = MPV_RENDER_API_TYPE_OPENGL;
        // Lets mpv map decoded frames straight into textures on Wayland.
        void *display = nullptr;
        if (auto *wayland = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>())
            display = wayland->display();
        mpv_render_param params[] = {
            { MPV_RENDER_PARAM_API_TYPE, const_cast<char *>(api) },
            { MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl },
            { display ? MPV_RENDER_PARAM_WL_DISPLAY : MPV_RENDER_PARAM_INVALID, display },
            { MPV_RENDER_PARAM_INVALID, nullptr },
        };
        if (mpv_render_context_create(&m_context, m_core->handle, params) < 0) {
            qWarning("MpvItem: could not create the render context");
            m_context = nullptr;
            return;
        }
        mpv_render_context_set_update_callback(m_context, [](void *data) {
            QMetaObject::invokeMethod(static_cast<MpvItem *>(data), &QQuickItem::update, Qt::QueuedConnection);
        }, m_item);
        QMetaObject::invokeMethod(m_item, &MpvItem::setReady, Qt::QueuedConnection);
    }

    MpvItem *m_item;
    std::shared_ptr<MpvCore> m_core;
    mpv_render_context *m_context = nullptr;
};

} // namespace

MpvItem::MpvItem(QQuickItem *parent) : QQuickFramebufferObject(parent), m_core(std::make_shared<MpvCore>()) {
    // libmpv refuses to start under any numeric locale but C.
    std::setlocale(LC_NUMERIC, "C");

    auto *mpv = mpv_create();
    m_core->handle = mpv;
    if (!mpv) {
        qWarning("MpvItem: could not create mpv");
        return;
    }
    mpv_set_option_string(mpv, "vo", "libmpv");
    mpv_set_option_string(mpv, "config", "no");
    mpv_set_option_string(mpv, "terminal", "no");
    mpv_set_option_string(mpv, "idle", "yes");
    mpv_set_option_string(mpv, "input-default-bindings", "no");
    mpv_set_option_string(mpv, "input-vo-keyboard", "no");
    mpv_set_option_string(mpv, "osc", "no");
    mpv_set_option_string(mpv, "hwdec", "auto-safe");
    mpv_request_log_messages(mpv, "info");
    mpv_set_wakeup_callback(mpv, [](void *data) {
        QMetaObject::invokeMethod(static_cast<MpvItem *>(data), [item = static_cast<MpvItem *>(data)] {
            item->drainEvents();
        }, Qt::QueuedConnection);
    }, this);
    if (mpv_initialize(mpv) < 0) qWarning("MpvItem: could not start mpv");
}

MpvItem::~MpvItem() {
    if (m_core->handle) mpv_set_wakeup_callback(m_core->handle, nullptr, nullptr);
}

QQuickFramebufferObject::Renderer *MpvItem::createRenderer() const {
    window()->setPersistentGraphics(true);
    window()->setPersistentSceneGraph(true);
    return new MpvRenderer(const_cast<MpvItem *>(this), m_core);
}

void MpvItem::setReady() {
    if (m_ready) return;
    m_ready = true;
    emit readyChanged();
}

void MpvItem::command(const QVariantList &args) {
    QList<QByteArray> storage;
    QList<const char *> argv;
    for (const auto &arg : args) storage.append(arg.toString().toUtf8());
    for (const auto &arg : storage) argv.append(arg.constData());
    argv.append(nullptr);
    mpv_command_async(m_core->handle, 0, argv.data());
}

void MpvItem::commandSync(const QVariantList &args) {
    QList<QByteArray> storage;
    QList<const char *> argv;
    for (const auto &arg : args) storage.append(arg.toString().toUtf8());
    for (const auto &arg : storage) argv.append(arg.constData());
    argv.append(nullptr);
    mpv_command(m_core->handle, argv.data());
}

void MpvItem::setProperty(const QString &name, const QVariant &value) {
    const auto key = name.toUtf8();
    switch (value.typeId()) {
    case QMetaType::Bool: {
        int flag = value.toBool();
        mpv_set_property(m_core->handle, key.constData(), MPV_FORMAT_FLAG, &flag);
        break;
    }
    case QMetaType::Int:
    case QMetaType::LongLong: {
        int64_t number = value.toLongLong();
        mpv_set_property(m_core->handle, key.constData(), MPV_FORMAT_INT64, &number);
        break;
    }
    case QMetaType::Double: {
        double number = value.toDouble();
        mpv_set_property(m_core->handle, key.constData(), MPV_FORMAT_DOUBLE, &number);
        break;
    }
    default:
        mpv_set_property_string(m_core->handle, key.constData(), value.toString().toUtf8().constData());
    }
}

QVariant MpvItem::getProperty(const QString &name) const {
    mpv_node node;
    if (mpv_get_property(m_core->handle, name.toUtf8().constData(), MPV_FORMAT_NODE, &node) < 0) return {};
    const auto value = fromNode(node);
    mpv_free_node_contents(&node);
    return value;
}

void MpvItem::observeProperty(const QString &name) {
    mpv_observe_property(m_core->handle, ++m_observers, name.toUtf8().constData(), MPV_FORMAT_NODE);
}

void MpvItem::drainEvents() {
    while (m_core->handle) {
        auto *event = mpv_wait_event(m_core->handle, 0);
        switch (event->event_id) {
        case MPV_EVENT_NONE: return;
        case MPV_EVENT_PROPERTY_CHANGE: {
            auto *property = static_cast<mpv_event_property *>(event->data);
            const auto value = property->format == MPV_FORMAT_NODE
                ? fromNode(*static_cast<mpv_node *>(property->data)) : QVariant();
            emit propertyChanged(QString::fromUtf8(property->name), value);
            break;
        }
        case MPV_EVENT_FILE_LOADED: emit fileLoaded(); break;
        case MPV_EVENT_END_FILE: {
            auto *end = static_cast<mpv_event_end_file *>(event->data);
            const char *reason = end->reason == MPV_END_FILE_REASON_EOF ? "eof"
                : end->reason == MPV_END_FILE_REASON_ERROR ? "error"
                : end->reason == MPV_END_FILE_REASON_STOP ? "stop" : "other";
            emit endFile(QString::fromLatin1(reason),
                end->error < 0 ? QString::fromUtf8(mpv_error_string(end->error)) : QString());
            break;
        }
        case MPV_EVENT_LOG_MESSAGE: {
            auto *log = static_cast<mpv_event_log_message *>(event->data);
            emit logMessage(QString::fromUtf8(log->level), QString::fromUtf8(log->prefix) + ": " + QString::fromUtf8(log->text).trimmed());
            break;
        }
        default: break;
        }
    }
}
