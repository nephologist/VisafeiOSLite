#import <Foundation/Foundation.h>

/**
 * DNS request processed event
 */
@interface AGDnsRequestProcessedEvent : NSObject
@property(nonatomic, readonly) NSString *domain; /**< Queried domain name */
@property(nonatomic, readonly) NSString *type; /**< Query type */
@property(nonatomic, readonly) NSInteger startTime; /**< Time when dnsproxy started processing request (epoch in milliseconds) */
@property(nonatomic, readonly) NSInteger elapsed; /**< Time elapsed on processing (in milliseconds) */
@property(nonatomic, readonly) NSString *answer; /**< DNS Answers string representation */
@property(nonatomic, readonly) NSString *upstreamAddr; /**< Address of the upstream used to resolve */
@property(nonatomic, readonly) NSUInteger bytesSent; /**< Number of bytes sent to a server */
@property(nonatomic, readonly) NSUInteger bytesReceived; /**< Number of bytes received from a server */
@property(nonatomic, readonly) NSArray<NSString *> *rules; /**< Filtering rules texts */
@property(nonatomic, readonly) NSArray<NSNumber *> *filterListIds; /**< Filter lists IDs of corresponding rules */
@property(nonatomic, readonly) BOOL whitelist; /**< True if filtering rule is whitelist */
@property(nonatomic, readonly) NSString *error; /**< If not empty, contains the error text (occurred while processing the DNS query) */
@end

/**
 * Set of DNS proxy events
 */
@interface AGDnsProxyEvents : NSObject
/**
 * Raised right after a request is processed.
 * Notes:
 *  - if there are several upstreams in proxy configuration, the proxy tries each one
 *    consequently until it gets successful status, so in this case each failed upstream
 *    fires the event - i.e., several events will be raised for the request
 */
@property (nonatomic, copy) void (^onRequestProcessed)(const AGDnsRequestProcessedEvent *event);
@end
